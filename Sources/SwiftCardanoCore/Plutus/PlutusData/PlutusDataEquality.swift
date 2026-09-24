@preconcurrency import BigInt
import Foundation

// `PlutusData` and its parts carry representation detail that carries no
// meaning on chain: a byte string is held as `.boundedBytes` or `.byteString`
// depending on its length, an integer as `.int`, `.bigUInt` or `.bigNInt`
// depending on its magnitude, a list as `.array` or `.indefiniteArray`
// depending on how it was written, and a ``Constr`` remembers whether its
// fields were encoded with an indefinite-length array.
//
// Swift's synthesised `==` compares all of that, so two values that encode to
// byte-identical CBOR could compare unequal — a datum read off the chain and
// the same value rebuilt in Swift routinely take different representations.
// The conformances below compare what the ledger compares: structure and
// content.
//
// `PlutusData` is used as a dictionary key, so `hash(into:)` has to agree with
// `==`. Each one ignores exactly the same representation detail.

extension Bytes {
    public static func == (lhs: Bytes, rhs: Bytes) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

extension BigInteger {
    public static func == (lhs: BigInteger, rhs: BigInteger) -> Bool {
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension Constr {
    public static func == (lhs: Constr, rhs: Constr) -> Bool {
        lhs.tag == rhs.tag && lhs.fields == rhs.fields
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(fields)
    }
}

extension PlutusData {
    /// The elements of a list, whichever of the two cases holds it, or `nil`
    /// when this is not a list.
    public var listElements: [PlutusData]? {
        switch self {
            case .array(let elements): return elements
            case .indefiniteArray(let elements): return elements.getAll()
            default: return nil
        }
    }

    public static func == (lhs: PlutusData, rhs: PlutusData) -> Bool {
        switch (lhs, rhs) {
            case (.constructor(let lhs), .constructor(let rhs)):
                return lhs == rhs

            case (.map(let lhs), .map(let rhs)):
                // A Plutus map is a list of pairs on chain, so its order is
                // part of its value. The pairs are walked here rather than
                // deferring to `OrderedDictionary`'s own `==` so that each
                // key and value is compared through this operator.
                guard lhs.count == rhs.count else { return false }
                return zip(lhs, rhs).allSatisfy { $0.key == $1.key && $0.value == $1.value }

            case (.bigInt(let lhs), .bigInt(let rhs)):
                return lhs == rhs

            case (.bytes(let lhs), .bytes(let rhs)):
                return lhs == rhs

            default:
                guard let lhs = lhs.listElements, let rhs = rhs.listElements else { return false }
                return lhs == rhs
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
            case .constructor(let constr):
                hasher.combine(0)
                hasher.combine(constr)
            case .map(let pairs):
                hasher.combine(1)
                hasher.combine(pairs.count)
                for (key, value) in pairs {
                    hasher.combine(key)
                    hasher.combine(value)
                }
            // The two list cases hold the same value, so they hash alike.
            case .array(let elements):
                hasher.combine(2)
                hasher.combine(elements)
            case .indefiniteArray(let elements):
                hasher.combine(2)
                hasher.combine(elements.getAll())
            case .bigInt(let value):
                hasher.combine(3)
                hasher.combine(value)
            case .bytes(let value):
                hasher.combine(4)
                hasher.combine(value)
        }
    }
}
