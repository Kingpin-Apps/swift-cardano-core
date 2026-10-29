@preconcurrency import BigInt
import CBORCodable
import Foundation

// The ledger reads metadata with no depth limit, so a metadatum can nest as
// deep as a transaction's size allows. Reading, writing, comparing, hashing,
// validating and freeing it all run in loops; the conversions to `Primitive`
// and to JSON are bounded by ``TransactionMetadatum/maxConversionDepth``.

extension TransactionMetadatum: NestedTree {
    mutating func moveChildren(into pending: inout [TransactionMetadatum]) {
        // Rebinding the payload and replacing `self` leaves the payload's
        // storage held once, so its children can be moved out of it.
        switch self {
        case .list(var elements):
            self = .int(0)
            elements.moveElements(into: &pending)
        case .map(var pairs):
            self = .int(0)
            pairs.moveKeysAndValues(into: &pending)
        case .int, .bigInt, .bytes, .text:
            break
        }
    }

    /// The children of this node, in order: elements, or each key followed
    /// by its value.
    var children: [TransactionMetadatum] {
        switch self {
        case .list(let elements): return elements.array
        case .map(let pairs): return pairs.elements.flatMap { [$0.key, $0.value] }
        case .int, .bigInt, .bytes, .text: return []
        }
    }

    /// Whether this value nests deeper than `limit` levels, found without
    /// visiting more of it than needed.
    func nests(deeperThan limit: Int) -> Bool {
        var pending: [(TransactionMetadatum, Int)] = [(self, 1)]
        while let (value, level) = pending.popLast() {
            if level > limit { return true }
            for child in value.children {
                pending.append((child, level + 1))
            }
        }
        return false
    }

    /// The deepest metadatum that is converted to a `Primitive` tree or to
    /// JSON, whose own code recurses: a deeper one's ``toPrimitive()``
    /// carries its encoded bytes instead, and ``toDict()`` throws.
    public static let maxConversionDepth = 128

    /// Equal when they hold the same structure and content, an integer
    /// whichever case carries it; compared node by node, without recursing.
    public static func == (lhs: TransactionMetadatum, rhs: TransactionMetadatum) -> Bool {
        var pending: [(TransactionMetadatum, TransactionMetadatum)] = [(lhs, rhs)]
        while let (lhs, rhs) = pending.popLast() {
            switch (lhs, rhs) {
            case (.map(let lhs), .map(let rhs)):
                guard lhs.count == rhs.count else { return false }
                for (left, right) in zip(lhs, rhs) {
                    pending.append((left.key, right.key))
                    pending.append((left.value, right.value))
                }
            case (.list(let lhs), .list(let rhs)):
                guard lhs.count == rhs.count else { return false }
                pending.append(contentsOf: zip(lhs, rhs))
            case (.bytes(let lhs), .bytes(let rhs)):
                guard lhs == rhs else { return false }
            case (.text(let lhs), .text(let rhs)):
                guard lhs == rhs else { return false }
            default:
                guard let lhs = lhs.integerValue, let rhs = rhs.integerValue, lhs == rhs else { return false }
            }
        }
        return true
    }

    /// Hashes node by node, without recursing. Each node gives its kind and,
    /// for a container, its size, so the sequence fixes the structure.
    public func hash(into hasher: inout Hasher) {
        var pending = [self]
        while let value = pending.popLast() {
            switch value {
            case .map(let pairs):
                hasher.combine(0)
                hasher.combine(pairs.count)
            case .list(let elements):
                hasher.combine(1)
                hasher.combine(elements.count)
            case .int, .bigInt:
                hasher.combine(2)
                hasher.combine(value.integerValue)
            case .bytes(let data):
                hasher.combine(3)
                hasher.combine(data)
            case .text(let text):
                hasher.combine(4)
                hasher.combine(text)
            }
            pending.append(contentsOf: value.children.reversed())
        }
    }
}

/// Writes a metadatum in a loop, as ``TransactionMetadatum/toPrimitive()``
/// would: definite-length lists and maps, every pair of a map in order.
enum MetadatumWriter {
    private enum Step {
        case value(TransactionMetadatum)
        case bytes(Data)
    }

    static func encode(_ root: TransactionMetadatum) throws -> Data {
        var data = Data()
        var steps: [Step] = [.value(root)]
        let encoder = CBOREncoder()
        while let step = steps.popLast() {
            switch step {
            case .bytes(let bytes):
                data.append(bytes)
            case .value(.list(let elements)):
                data.append(CBORItemScanner.definiteHeader(major: 4, count: elements.count))
                steps.append(contentsOf: elements.reversed().map { .value($0) })
            case .value(.map(let pairs)):
                data.append(CBORItemScanner.definiteHeader(major: 5, count: pairs.count))
                for pair in pairs.elements.reversed() {
                    steps.append(.value(pair.value))
                    steps.append(.value(pair.key))
                }
            case .value(let scalar):
                data.append(try encoder.encode(scalar.primitive()))
            }
        }
        return data
    }
}
