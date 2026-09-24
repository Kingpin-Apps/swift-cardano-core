import Foundation
@preconcurrency import BigInt
import CBORCodable
import OrderedCollections

/// Representation of a big integer according to the CDDL's `big_int` description:
/// big_int = int / big_uint / big_nint
/// big_uint = #6.2(bounded_bytes)
/// big_nint = #6.3(bounded_bytes)
///
/// This enum keeps small signed ints (that fit in Int64) separately and otherwise stores
/// magnitude bytes for big unsigned/negative integers.
public enum BigInteger: Serializable, CustomStringConvertible, Sendable {
    case int(Int64)         // small (fits in Int64)
    case bigUInt(BigUInt)      // magnitude bytes for a large unsigned integer (CBOR tag 2)
    case bigNInt(BigInt)      // magnitude bytes for a large negative integer (CBOR tag 3)
    
    public var description: String {
        switch self {
            case .int(let v): return "Int(\(v))"
            case .bigUInt(let d): return "BigUInt(\(d))"
            case .bigNInt(let d): return "BigNInt(\(d))"
        }
    }
    
    /// The integer this holds, whichever case carries it.
    public var value: BigInt {
        switch self {
            case .int(let value): return BigInt(value)
            case .bigUInt(let value): return BigInt(value)
            case .bigNInt(let value): return value
        }
    }
    
    /// The integer itself, narrowed to `Int64`. Traps when it does not fit;
    /// use ``value`` to keep the full range.
    public var intValue : Int64 {
        return Int64(value)
    }
    
    /// The integer's magnitude, with its sign dropped.
    public var bigUIntValue : BigUInt {
        return value.magnitude
    }
    
    public var bigNIntValue : BigInt {
        return value
    }
    
    /// Convenience initializer for unsigned magnitude bytes.
    /// The bytes are expected in big-endian form.
    public init(bigUIntBytes bigUInt: BigUInt) throws {
        self = .bigUInt(bigUInt)
    }
    
    /// Convenience initializer for negative magnitude bytes.
    /// The bytes are expected in big-endian form for the absolute value.
    public init(bigNIntBytes bigNInt: BigInt) throws {
        self = .bigNInt(bigNInt)
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .int(let v):
                self = .int(v)
            case .uint(let v):
                // An unsigned value above `Int64.max` still fits CBOR's
                // unsigned integer, so it cannot be narrowed here.
                if let small = Int64(exactly: v) {
                    self = .int(small)
                } else {
                    self = .bigUInt(BigUInt(v))
                }
            case .bigUInt(let value):
                self = .bigUInt(value)
            case .bigInt(let value):
                self = value.sign == .plus ? .bigUInt(value.magnitude) : .bigNInt(value)
            case .cborTag(let tag) where tag.tag == 2:
                self = .bigUInt(try Self.magnitude(ofBignum: tag))
            case .cborTag(let tag) where tag.tag == 3:
                // Tag 3 carries -1 - n, so the value is one below the
                // negated magnitude.
                self = .bigNInt(-1 - BigInt(try Self.magnitude(ofBignum: tag)))
            default:
                throw CardanoCoreError.deserializeError("Invalid BigInt type: \(primitive)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        // An integer is written as a CBOR bignum only when it does not fit in
        // 64 bits, which is the rule the ledger follows. Normalising here is
        // what makes two equal values encode alike — and so hash alike —
        // however each of them happens to be held.
        let value = self.value
        if let small = Int64(exactly: value) {
            return .int(small)
        }
        if value.sign == .plus {
            if let unsigned = UInt64(exactly: value.magnitude) {
                return .uint(unsigned)
            }
            return .cborTag(CBORTag(tag: 2, value: .bytes(value.magnitude.serialize())))
        }
        // Tag 3 carries -1 - n, so what goes on the wire is one below the
        // magnitude.
        return .cborTag(CBORTag(tag: 3, value: .bytes((value.magnitude - 1).serialize())))
    }
    
    /// The big-endian magnitude carried by a CBOR bignum tag.
    private static func magnitude(ofBignum tag: CBORTag) throws -> BigUInt {
        switch tag.value {
            case .bytes(let data):
                return BigUInt(data)
            case .byteArray(let bytes):
                return BigUInt(Data(bytes))
            case .byteString(let byteString):
                return BigUInt(byteString.bytes)
            default:
                throw CardanoCoreError.deserializeError(
                    "Invalid bignum CBOR tag value: \(tag.value)"
                )
        }
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ data: Primitive) throws -> BigInteger {
        guard case let .orderedDict(orderedDict) = data else {
            throw CardanoCoreError.deserializeError("Invalid BigInteger dict format")
        }
        if case let .int(intData) = orderedDict[.string("int")] {
            return .int(Int64(intData))
        } else if case let .uint(intData) = orderedDict[.string("int")] {
            return .bigUInt(BigUInt(intData))
        } else if case let .bigInt(intData) = orderedDict[.string("int")] {
            return .bigNInt(intData)
        } else if case let .bigUInt(intData) = orderedDict[.string("int")] {
            return .bigUInt(intData)
        } else {
            throw CardanoCoreError.deserializeError("Invalid BigInteger dict: \(orderedDict)")
        }
    }
    
    public func toDict() throws -> Primitive {
        switch self {
            case .int(let value):
                return .orderedDict([.string("int"): .int(value)])
            case .bigUInt(let value):
                return .orderedDict([.string("int"): .bigUInt(value)])
            case .bigNInt(let value):
                return .orderedDict([.string("int"): .bigInt(value)])
        }
    }
}
