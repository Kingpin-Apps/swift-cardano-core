import Foundation

// The ledger reads Plutus data with no depth limit, so a datum can nest as
// deep as a transaction's size allows. Reading, writing, hashing, comparing,
// describing and freeing it all run in loops; the conversions to `Primitive`
// and to JSON, which build nested values of their own, are bounded by
// ``PlutusData/maxConversionDepth``.

extension PlutusData: NestedTree {
    mutating func moveChildren(into pending: inout [PlutusData]) {
        // Rebinding the payload and replacing `self` leaves the payload's
        // storage held once, so its children can be moved out of it.
        switch self {
        case .array(var elements):
            self = .bigInt(.int(0))
            elements.moveElements(into: &pending)
        case .indefiniteArray(var elements):
            self = .bigInt(.int(0))
            elements.moveItems(into: &pending)
        case .constructor(var constr):
            self = .bigInt(.int(0))
            constr.fieldList.moveElements(into: &pending)
        case .map(var pairs), .indefiniteMap(var pairs):
            self = .bigInt(.int(0))
            pairs.moveKeysAndValues(into: &pending)
        case .bigInt, .bytes:
            break
        }
    }

    /// The children of this node, in order: fields, elements, or each key
    /// followed by its value.
    var children: [PlutusData] {
        switch self {
        case .constructor(let constr): return constr.fields
        case .array(let elements): return elements.array
        case .indefiniteArray(let elements): return elements.getAll()
        case .map(let pairs), .indefiniteMap(let pairs):
            return pairs.elements.flatMap { [$0.key, $0.value] }
        case .bigInt, .bytes: return []
        }
    }

    /// How many levels this value nests: 1 for an integer or byte string, one
    /// more for each list, map or constructor around it. Counted in a loop.
    public var depth: Int {
        var deepest = 0
        var pending: [(PlutusData, Int)] = [(self, 1)]
        while let (value, level) = pending.popLast() {
            deepest = max(deepest, level)
            for child in value.children {
                pending.append((child, level + 1))
            }
        }
        return deepest
    }

    /// Whether this value nests deeper than `limit` levels, found without
    /// visiting more of it than needed.
    func nests(deeperThan limit: Int) -> Bool {
        var pending: [(PlutusData, Int)] = [(self, 1)]
        while let (value, level) = pending.popLast() {
            if level > limit { return true }
            for child in value.children {
                pending.append((child, level + 1))
            }
        }
        return false
    }

    /// The deepest value that is converted to a `Primitive` tree or to JSON.
    ///
    /// Those conversions build nested values whose own code recurses, so they
    /// are kept within a depth that is safe on a 512 KB thread stack. A
    /// deeper value's ``toPrimitive()`` carries its encoded bytes instead, and
    /// ``toDict()`` throws.
    public static let maxConversionDepth = 128

    /// A description of the value, written in a loop.
    public var debugDescription: String {
        enum Step {
            case value(PlutusData)
            case text(String)
        }
        var text = ""
        var steps: [Step] = [.value(self)]
        func push(_ open: String, _ items: [Step], separator: String, close: String) {
            text += open
            steps.append(.text(close))
            for (index, item) in items.enumerated().reversed() {
                steps.append(item)
                if index > 0 { steps.append(.text(separator)) }
            }
        }
        while let step = steps.popLast() {
            switch step {
            case .text(let string):
                text += string
            case .value(.constructor(let constr)):
                push("constructor(tag: \(String(describing: constr.tag)), fields: [",
                     constr.fields.map { .value($0) }, separator: ", ", close: "])")
            case .value(.array(let elements)):
                push("array([", elements.map { .value($0) }, separator: ", ", close: "])")
            case .value(.indefiniteArray(let elements)):
                push("indefiniteArray([", elements.map { .value($0) }, separator: ", ", close: "])")
            case .value(.map(let pairs)), .value(.indefiniteMap(let pairs)):
                let name = if case .value(.map) = step { "map" } else { "indefiniteMap" }
                text += "\(name)(["
                steps.append(.text("])"))
                for (index, pair) in pairs.elements.enumerated().reversed() {
                    steps.append(.value(pair.value))
                    steps.append(.text(": "))
                    steps.append(.value(pair.key))
                    if index > 0 { steps.append(.text(", ")) }
                }
            case .value(.bigInt(let integer)):
                text += "bigInt(\(integer))"
            case .value(.bytes(let bytes)):
                text += "bytes(size: \(bytes.count))"
            }
        }
        return text
    }

    public var description: String { debugDescription }
}
