@preconcurrency import BigInt
import Foundation

/// Reads Plutus data straight from its bytes.
///
/// The generic CBOR layer holds a map as a dictionary, so a map that repeats a
/// key — which the ledger accepts in Plutus data, where a map is a list of
/// pairs — would lose a pair on the way. This reads the bytes itself. It keeps
/// every pair, and how each list, map, byte string and constructor was
/// written, and it rejects what the ledger does not read as Plutus data: text
/// strings, floats, simple values and tags other than constructors and
/// bignums.
struct PlutusDataReader {
    let scanner: CBORItemScanner

    /// The ledger sets no depth limit on Plutus data, and neither does this:
    /// reading is iterative, and so are writing, hashing, `==`, describing
    /// and freeing the value read, so any depth a transaction can hold is
    /// read on a small thread stack.
    init(_ bytes: Data) {
        scanner = CBORItemScanner(bytes)
    }

    /// The datum that makes up all of the bytes.
    static func read(_ bytes: Data) throws -> PlutusData {
        let reader = PlutusDataReader(bytes)
        let (value, end) = try reader.read(at: 0)
        guard end == reader.scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after PlutusData")
        }
        return value
    }

    /// A list, map or constructor whose items are still being read.
    private struct Frame {
        enum Kind {
            case list
            case map
            /// A constructor; `closesOuter` when it is a `#6.102` whose
            /// `[alternative, fields]` array was written indefinite, so a
            /// break follows the fields.
            case constructor(alternative: UInt64, general: Bool, closesOuter: Bool)
        }
        var kind: Kind
        var items: [PlutusData] = []
        /// How many items are left to read, or `nil` until a break.
        var remaining: UInt64?
        /// Whether it was written with an indefinite length.
        let indefinite: Bool
        /// Where it starts, for errors.
        let offset: Int

        init(_ kind: Kind, remaining: UInt64?, offset: Int) {
            self.kind = kind
            self.remaining = remaining
            self.indefinite = remaining == nil
            self.offset = offset
        }

        mutating func add(_ item: PlutusData) {
            items.append(item)
            if let remaining { self.remaining = remaining - 1 }
        }
    }

    /// The datum that starts at `offset`, and the offset just past it.
    ///
    /// Iterative, with the containers being read kept in an array, so that
    /// how deep the datum is costs no stack.
    func read(at offset: Int) throws -> (PlutusData, end: Int) {
        var stack: [Frame] = []
        var position = offset
        while true {
            var value: PlutusData
            if let top = stack.last, try isComplete(top, at: &position) {
                stack.removeLast()
                value = try finish(top, at: &position)
            } else {
                let header = try scanner.header(at: position)
                switch (header.major, header.argument) {
                case (0, let argument?):
                    value = .bigInt(Self.integer(BigInt(argument)))
                    position = header.end
                case (1, let argument?):
                    value = .bigInt(Self.integer(-1 - BigInt(argument)))
                    position = header.end
                case (2, _):
                    let (bytes, end) = try byteString(at: position)
                    value = .bytes(bytes)
                    position = end
                case (4, let count):
                    stack.append(Frame(.list, remaining: count, offset: position))
                    position = header.end
                    continue
                case (5, let count):
                    // Every item takes at least a byte, so a count beyond the
                    // bytes is truncated; checking first keeps the doubling in range.
                    if let count, count > UInt64(scanner.bytes.count) {
                        throw CardanoCoreError.deserializeError("Truncated PlutusData map at byte \(position)")
                    }
                    stack.append(Frame(.map, remaining: count.map { $0 * 2 }, offset: position))
                    position = header.end
                    continue
                case (6, 2?), (6, 3?):
                    let (magnitude, end) = try byteString(at: header.end)
                    let magnitudeValue = BigInt(BigUInt(magnitude.data))
                    value = .bigInt(Self.integer(header.argument == 2 ? magnitudeValue : -1 - magnitudeValue))
                    position = end
                case (6, let tag?) where (121...127).contains(tag) || (1280...1400).contains(tag):
                    let alternative = tag < 1280 ? tag - 121 : tag - 1280 + 7
                    let fields = try scanner.header(at: header.end)
                    guard fields.major == 4 else {
                        throw CardanoCoreError.deserializeError(
                            "A constructor's fields must be an array, at byte \(header.end)")
                    }
                    stack.append(Frame(
                        .constructor(alternative: alternative, general: false, closesOuter: false),
                        remaining: fields.argument, offset: position))
                    position = fields.end
                    continue
                case (6, 102?):
                    // #6.102([alternative, [* plutus_data]])
                    let outer = try scanner.header(at: header.end)
                    let alternative = try scanner.header(at: outer.end)
                    guard outer.major == 4, outer.argument == nil || outer.argument == 2,
                        alternative.major == 0, let alternativeValue = alternative.argument
                    else {
                        throw CardanoCoreError.deserializeError(
                            "A #6.102 constructor must be [alternative, fields], at byte \(position)")
                    }
                    let fields = try scanner.header(at: alternative.end)
                    guard fields.major == 4 else {
                        throw CardanoCoreError.deserializeError("Malformed #6.102 constructor at byte \(position)")
                    }
                    stack.append(Frame(
                        .constructor(alternative: alternativeValue, general: true, closesOuter: outer.argument == nil),
                        remaining: fields.argument, offset: position))
                    position = fields.end
                    continue
                case (6, let tag?):
                    throw CardanoCoreError.deserializeError("Not Plutus data: CBOR tag \(tag) at byte \(position)")
                default:
                    throw CardanoCoreError.deserializeError(
                        "Not Plutus data: CBOR major type \(header.major) at byte \(position)")
                }
            }
            guard !stack.isEmpty else { return (value, position) }
            stack[stack.count - 1].add(value)
        }
    }

    /// Whether every item of `frame` has been read; past the break, if it
    /// ends with one.
    private func isComplete(_ frame: Frame, at position: inout Int) throws -> Bool {
        if let remaining = frame.remaining { return remaining == 0 }
        guard try byte(at: position) == 0xFF else { return false }
        position += 1
        return true
    }

    /// The value of a container whose items have all been read.
    private func finish(_ frame: Frame, at position: inout Int) throws -> PlutusData {
        switch frame.kind {
        case .list:
            return frame.indefinite ? .indefiniteArray(IndefiniteList(frame.items)) : .array(frame.items)
        case .map:
            guard frame.items.count % 2 == 0 else {
                throw CardanoCoreError.deserializeError("A map key without a value, in the map at byte \(frame.offset)")
            }
            var pairs = MapPairs<PlutusData, PlutusData>()
            for index in stride(from: 0, to: frame.items.count, by: 2) {
                pairs.append(key: frame.items[index], value: frame.items[index + 1])
            }
            return frame.indefinite ? .indefiniteMap(pairs) : .map(pairs)
        case .constructor(let alternative, let general, let closesOuter):
            if closesOuter {
                guard try byte(at: position) == 0xFF else {
                    throw CardanoCoreError.deserializeError(
                        "A #6.102 constructor must be [alternative, fields], at byte \(frame.offset)")
                }
                position += 1
            }
            var constr = Self.constr(alternative, frame.items, indefinite: frame.indefinite, general: general)
            constr.writtenGeneralIndefinite = closesOuter
            return .constructor(constr)
        }
    }

    /// An integer, held as ``BigInteger/int(_:)`` when it fits.
    static func integer(_ value: BigInt) -> BigInteger {
        if let small = Int64(exactly: value) { return .int(small) }
        return value.sign == .plus ? .bigUInt(value.magnitude) : .bigNInt(value)
    }

    /// A byte string, definite or in chunks, keeping the chunks.
    private func byteString(at offset: Int) throws -> (Bytes, end: Int) {
        let header = try scanner.header(at: offset)
        guard header.major == 2 else {
            throw CardanoCoreError.deserializeError("Expected a byte string at byte \(offset)")
        }
        if let length = header.argument {
            let end = try scanner.end(ofItemAt: offset)
            _ = length
            return (try Bytes(from: scanner.bytes.subdata(in: header.end..<end)), end)
        }
        var chunks: [Data] = []
        var position = header.end
        while scanner.bytes[safe: position] != 0xFF {
            let chunk = try scanner.header(at: position)
            guard chunk.major == 2, chunk.argument != nil else {
                throw CardanoCoreError.deserializeError(
                    "A chunk of a byte string must be a definite byte string, at byte \(position)")
            }
            let end = try scanner.end(ofItemAt: position)
            chunks.append(scanner.bytes.subdata(in: chunk.end..<end))
            position = end
        }
        guard position < scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Truncated byte string at byte \(offset)")
        }
        return (.byteString(ByteString(chunks: chunks)), position + 1)
    }

    private static func constr(
        _ alternative: UInt64, _ fields: [PlutusData], indefinite: Bool, general: Bool
    ) -> Constr {
        var constr = Constr(tag: alternative, fields: fields, useIndefiniteList: indefinite)
        constr.writtenIndefinite = indefinite
        constr.writtenGeneral = general
        return constr
    }

    private func byte(at offset: Int) throws -> UInt8 {
        guard let byte = scanner.bytes[safe: offset] else {
            throw CardanoCoreError.deserializeError("Truncated PlutusData at byte \(offset)")
        }
        return byte
    }
}

extension Data {
    subscript(safe offset: Int) -> UInt8? {
        offset >= 0 && offset < count ? self[startIndex + offset] : nil
    }
}
