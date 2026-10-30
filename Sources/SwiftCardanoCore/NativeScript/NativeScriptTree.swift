import CBORCodable
import Foundation

// The ledger reads native scripts with no depth limit — preprod holds one
// nested 5,383 deep — so a script can nest as deep as a transaction's size
// allows. Reading, writing, hashing, comparing, describing and freeing it all
// run in loops; the conversions to `Primitive` and to JSON are bounded by
// ``NativeScript/maxConversionDepth``.

extension NativeScript: NestedTree {
    mutating func moveChildren(into pending: inout [NativeScript]) {
        // Rebinding the payload and replacing `self` leaves the payload's
        // storage held once, so its children can be moved out of it.
        switch self {
        case .scriptAll(var script):
            self = .invalidBefore(BeforeScript(slot: 0))
            script.scriptList.moveElements(into: &pending)
        case .scriptAny(var script):
            self = .invalidBefore(BeforeScript(slot: 0))
            script.scriptList.moveElements(into: &pending)
        case .scriptNofK(var script):
            self = .invalidBefore(BeforeScript(slot: 0))
            script.scriptList.moveElements(into: &pending)
        case .scriptPubkey, .invalidBefore, .invalidHereAfter:
            break
        }
    }

    /// The scripts this one holds, in order.
    var children: [NativeScript] {
        switch self {
        case .scriptAll(let script): return script.scripts
        case .scriptAny(let script): return script.scripts
        case .scriptNofK(let script): return script.scripts
        case .scriptPubkey, .invalidBefore, .invalidHereAfter: return []
        }
    }

    /// Whether this script nests deeper than `limit` levels, found without
    /// visiting more of it than needed.
    func nests(deeperThan limit: Int) -> Bool {
        var pending: [(NativeScript, Int)] = [(self, 1)]
        while let (script, level) = pending.popLast() {
            if level > limit { return true }
            for child in script.children {
                pending.append((child, level + 1))
            }
        }
        return false
    }

    /// The deepest script that is converted to a `Primitive` tree or to JSON,
    /// whose own code recurses: a deeper one's ``toPrimitive()`` carries its
    /// encoded bytes instead, and ``toDict()`` throws.
    public static let maxConversionDepth = 128

    /// Equal when they are the same script, compared node by node without
    /// recursing.
    public static func == (lhs: NativeScript, rhs: NativeScript) -> Bool {
        var pending: [(NativeScript, NativeScript)] = [(lhs, rhs)]
        while let (lhs, rhs) = pending.popLast() {
            switch (lhs, rhs) {
            case (.scriptPubkey(let lhs), .scriptPubkey(let rhs)):
                guard lhs == rhs else { return false }
            case (.invalidBefore(let lhs), .invalidBefore(let rhs)):
                guard lhs == rhs else { return false }
            case (.invalidHereAfter(let lhs), .invalidHereAfter(let rhs)):
                guard lhs == rhs else { return false }
            case (.scriptNofK(let lhs), .scriptNofK(let rhs)):
                guard lhs.required == rhs.required else { return false }
                fallthrough
            case (.scriptAll, .scriptAll), (.scriptAny, .scriptAny):
                // Also reached by fallthrough from two scriptNofK with the same `required`.
                let (left, right) = (lhs.children, rhs.children)
                guard left.count == right.count else { return false }
                pending.append(contentsOf: zip(left, right))
            default:
                return false
            }
        }
        return true
    }

    /// Hashes node by node, without recursing. Each node gives its kind and,
    /// for a container, its size, so the sequence fixes the structure.
    public func hash(into hasher: inout Hasher) {
        var pending = [self]
        while let script = pending.popLast() {
            switch script {
            case .scriptPubkey(let script):
                hasher.combine(0)
                hasher.combine(script)
            case .scriptAll(let script):
                hasher.combine(1)
                hasher.combine(script.scriptList.count)
            case .scriptAny(let script):
                hasher.combine(2)
                hasher.combine(script.scriptList.count)
            case .scriptNofK(let script):
                hasher.combine(3)
                hasher.combine(script.required)
                hasher.combine(script.scriptList.count)
            case .invalidBefore(let script):
                hasher.combine(4)
                hasher.combine(script)
            case .invalidHereAfter(let script):
                hasher.combine(5)
                hasher.combine(script)
            }
            pending.append(contentsOf: script.children.reversed())
        }
    }

    /// A description of the script, written in a loop.
    public var description: String {
        enum Step {
            case script(NativeScript)
            case text(String)
        }
        var text = ""
        var steps: [Step] = [.script(self)]
        while let step = steps.popLast() {
            switch step {
            case .text(let string):
                text += string
            case .script(let script):
                let open: String
                switch script {
                case .scriptPubkey(let script): text += "sig(\(script.keyHash))"; continue
                case .invalidBefore(let script): text += "after(\(script.slot))"; continue
                case .invalidHereAfter(let script): text += "before(\(script.slot))"; continue
                case .scriptAll: open = "all(["
                case .scriptAny: open = "any(["
                case .scriptNofK(let script): open = "atLeast(\(script.required), ["
                }
                text += open
                steps.append(.text("])"))
                for (index, child) in script.children.enumerated().reversed() {
                    steps.append(.script(child))
                    if index > 0 { steps.append(.text(", ")) }
                }
            }
        }
        return text
    }
}

/// Reads a native script from its bytes in a loop, so that any depth costs
/// no stack, as the ledger reads one: each record and each list of scripts of
/// definite or indefinite length (`decodeRecordSum`, `decodeStrictSeq`), any
/// integer width. The script read keeps its bytes, as the ledger's memoised
/// `Timelock` does, so that its hash is taken over them.
enum NativeScriptReader {
    private struct Frame {
        let type: UInt64
        let required: Int
        /// Whether the record `[type, …, [scripts]]` was written with an
        /// indefinite length, so a break follows the list of scripts.
        let indefiniteRecord: Bool
        var scripts: [NativeScript] = []
        /// Scripts left to read, or `nil` until a break.
        var remaining: UInt64?
    }

    static func read(_ bytes: Data) throws -> NativeScript {
        let scanner = CBORItemScanner(bytes)
        var stack: [Frame] = []
        var position = 0
        func byte(at offset: Int) throws -> UInt8 {
            guard let byte = bytes[safe: offset] else {
                throw CardanoCoreError.deserializeError("Truncated native script at byte \(offset)")
            }
            return byte
        }
        while true {
            var script: NativeScript
            if let top = stack.last, try top.remaining.map({ $0 == 0 }) ?? (byte(at: position) == 0xFF) {
                stack.removeLast()
                if top.remaining == nil { position += 1 }
                if top.indefiniteRecord {
                    guard try byte(at: position) == 0xFF else {
                        throw CardanoCoreError.deserializeError("Excess terms in a native script at byte \(position)")
                    }
                    position += 1
                }
                script = switch top.type {
                case 1: .scriptAll(ScriptAll(scripts: top.scripts))
                case 2: .scriptAny(ScriptAny(scripts: top.scripts))
                default: .scriptNofK(ScriptNofK(required: top.required, scripts: top.scripts))
                }
            } else {
                let record = try scanner.header(at: position)
                guard record.major == 4 else {
                    throw CardanoCoreError.decodingError("NativeScript expected a CBOR array at byte \(position)")
                }
                let typeHeader = try scanner.header(at: record.end)
                guard typeHeader.major == 0, let type = typeHeader.argument else {
                    throw CardanoCoreError.decodingError(
                        "NativeScript: expected first element to be unsigned int at byte \(record.end)")
                }
                let fields: UInt64 = type == 3 ? 3 : 2
                if let count = record.argument, count != fields {
                    throw CardanoCoreError.deserializeError(
                        "A native script of type \(type) has \(fields) fields, got \(count), at byte \(position)")
                }
                var offset = typeHeader.end
                switch type {
                case 1, 2, 3:
                    var required = 0
                    if type == 3 {
                        // script_n_of_k = (3, n : int64, [* native_script])
                        let end = try scanner.end(ofItemAt: offset)
                        required = try Primitive.from(
                            cbor: CBORDecoder.ledger().decode(CBOR.self, from: bytes.subdata(in: offset..<end))
                        ).integer("ScriptNofK required", as: Int.self)
                        offset = end
                    }
                    let list = try scanner.header(at: offset)
                    guard list.major == 4 else {
                        throw CardanoCoreError.deserializeError("Invalid native script list at byte \(offset)")
                    }
                    if let count = list.argument, count > UInt64(bytes.count - list.end) {
                        throw CardanoCoreError.deserializeError("Truncated native script list at byte \(offset)")
                    }
                    stack.append(Frame(
                        type: type, required: required, indefiniteRecord: record.argument == nil,
                        remaining: list.argument))
                    position = list.end
                    continue
                case 0, 4, 5:
                    // A key hash or a slot, read as the script's own decoder reads it.
                    let end = try scanner.end(ofItemAt: offset)
                    let field = try Primitive.from(
                        cbor: CBORDecoder.ledger().decode(CBOR.self, from: bytes.subdata(in: offset..<end)))
                    script = try NativeScript(from: .list([.uint(type), field.normalized()]))
                    position = end
                    if record.argument == nil {
                        guard try byte(at: position) == 0xFF else {
                            throw CardanoCoreError.deserializeError("Excess terms in a native script at byte \(position)")
                        }
                        position += 1
                    }
                default:
                    throw CardanoCoreError.decodingError("NativeScript: unknown script type \(type)")
                }
            }
            guard !stack.isEmpty else {
                guard position == bytes.count else {
                    throw CardanoCoreError.deserializeError("Trailing bytes after a native script")
                }
                script.originalCBOR = bytes
                return script
            }
            stack[stack.count - 1].scripts.append(script)
            if let remaining = stack[stack.count - 1].remaining {
                stack[stack.count - 1].remaining = remaining - 1
            }
        }
    }
}

extension NativeScript {
    /// The scripts of the list — tagged as a set or not — that starts at
    /// `offset`, each read from its bytes and keeping them.
    static func read(_ scanner: CBORItemScanner, arrayAt offset: Int) throws -> [NativeScript] {
        try scanner.elements(ofArrayAt: scanner.untagged(at: offset)).map {
            try NativeScriptReader.read(scanner.bytes.subdata(in: $0))
        }
    }
}

/// Writes a native script in a loop, as ``NativeScript/toPrimitive()`` would.
enum NativeScriptWriter {
    private enum Step {
        case script(NativeScript)
        case bytes(Data)
    }

    static func encode(_ root: NativeScript) throws -> Data {
        var data = Data()
        var steps: [Step] = [.script(root)]
        let encoder = CBOREncoder()
        while let step = steps.popLast() {
            switch step {
            case .bytes(let bytes):
                data.append(bytes)
            case .script(let script):
                if let originalCBOR = script.originalCBOR {
                    data.append(originalCBOR)
                    continue
                }
                let children = script.children
                switch script {
                case .scriptAll:
                    data.append(contentsOf: [0x82, 0x01])
                case .scriptAny:
                    data.append(contentsOf: [0x82, 0x02])
                case .scriptNofK(let script):
                    data.append(contentsOf: [0x83, 0x03])
                    data.append(try encoder.encode(Primitive.integer(script.required)))
                case .scriptPubkey, .invalidBefore, .invalidHereAfter:
                    data.append(try encoder.encode(script.primitive()))
                    continue
                }
                data.append(CBORItemScanner.definiteHeader(major: 4, count: children.count))
                steps.append(contentsOf: children.reversed().map { .script($0) })
            }
        }
        return data
    }
}
