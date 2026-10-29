@preconcurrency import BigInt
import Foundation
import OrderedCollections

// `PlutusData` and its parts carry representation detail that carries no
// meaning on chain: a byte string is held as `.boundedBytes` or `.byteString`
// depending on its length, an integer as `.int`, `.bigUInt` or `.bigNInt`
// depending on its magnitude, a list as `.array` or `.indefiniteArray` and a
// map as `.map` or `.indefiniteMap` depending on how they were written, a byte
// string remembers the chunks it was read in, and a ``Constr`` remembers
// whether its fields were encoded with an indefinite-length array.
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
        PlutusData.combine(fields, into: &hasher)
    }
}

extension PlutusData {
    /// The elements of a list, whichever of the two cases holds it, or `nil`
    /// when this is not a list.
    public var listElements: [PlutusData]? {
        switch self {
            case .array(let elements): return elements.array
            case .indefiniteArray(let elements): return elements.getAll()
            default: return nil
        }
    }

    /// The pairs of a map, whichever of the two cases holds it, or `nil`
    /// when this is not a map.
    public var mapEntries: MapPairs<PlutusData, PlutusData>? {
        switch self {
            case .map(let pairs), .indefiniteMap(let pairs): return pairs
            default: return nil
        }
    }

    /// Equal when they hold the same structure and content, compared node
    /// by node without recursing, so that deeply nested values compare on a
    /// small thread stack.
    public static func == (lhs: PlutusData, rhs: PlutusData) -> Bool {
        var pending: [(PlutusData, PlutusData)] = [(lhs, rhs)]
        while let (lhs, rhs) = pending.popLast() {
            switch (lhs, rhs) {
                case (.constructor(let lhs), .constructor(let rhs)):
                    guard lhs.tag == rhs.tag, lhs.fieldList.count == rhs.fieldList.count else { return false }
                    pending.append(contentsOf: zip(lhs.fieldList, rhs.fieldList))

                case (.map(let lhs), .map(let rhs)), (.map(let lhs), .indefiniteMap(let rhs)),
                    (.indefiniteMap(let lhs), .map(let rhs)),
                    (.indefiniteMap(let lhs), .indefiniteMap(let rhs)):
                    // A Plutus map is a list of pairs on chain, so its order —
                    // and any repeated key — is part of its value.
                    guard lhs.count == rhs.count else { return false }
                    for (left, right) in zip(lhs, rhs) {
                        pending.append((left.key, right.key))
                        pending.append((left.value, right.value))
                    }

                case (.bigInt(let lhs), .bigInt(let rhs)):
                    guard lhs == rhs else { return false }

                case (.bytes(let lhs), .bytes(let rhs)):
                    guard lhs == rhs else { return false }

                default:
                    guard let lhs = lhs.listElements, let rhs = rhs.listElements,
                          lhs.count == rhs.count else { return false }
                    pending.append(contentsOf: zip(lhs, rhs))
            }
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        Self.combine([self], into: &hasher)
    }

    /// Hashes `values` node by node, in order, without recursing, so that a
    /// deeply nested value hashes on a small thread stack. Each node gives
    /// its kind and, for a container, its size, so the sequence fixes the
    /// structure. The two list cases, and the two map cases, hash alike, as
    /// `==` holds them equal.
    static func combine(_ values: [PlutusData], into hasher: inout Hasher) {
        var pending = Array(values.reversed())
        while let value = pending.popLast() {
            switch value {
                case .constructor(let constr):
                    hasher.combine(0)
                    hasher.combine(constr.tag)
                    hasher.combine(constr.fields.count)
                    pending.append(contentsOf: constr.fields.reversed())
                case .map(let pairs), .indefiniteMap(let pairs):
                    hasher.combine(1)
                    hasher.combine(pairs.count)
                    for (key, value) in Array(pairs).reversed() {
                        pending.append(value)
                        pending.append(key)
                    }
                case .array, .indefiniteArray:
                    let elements = value.listElements ?? []
                    hasher.combine(2)
                    hasher.combine(elements.count)
                    pending.append(contentsOf: elements.reversed())
                case .bigInt(let integer):
                    hasher.combine(3)
                    hasher.combine(integer)
                case .bytes(let bytes):
                    hasher.combine(4)
                    hasher.combine(bytes)
            }
        }
    }
}
