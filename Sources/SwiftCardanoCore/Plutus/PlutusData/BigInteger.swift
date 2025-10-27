import BigInt
import PotentCBOR
import OrderedCollections

/// Representation of a big integer according to the CDDL's `big_int` description:
/// big_int = int / big_uint / big_nint
/// big_uint = #6.2(bounded_bytes)
/// big_nint = #6.3(bounded_bytes)
///
/// This enum keeps small signed ints (that fit in Int64) separately and otherwise stores
/// magnitude bytes for big unsigned/negative integers.
public enum BigInteger: Serializable, CustomStringConvertible {
    case int(Int64)         // small (fits in Int64)
    case bigUInt(BigUInt)      // magnitude bytes for a large unsigned integer (CBOR tag 2)
    case bigNInt(BigInt)      // magnitude bytes for a large negative integer (CBOR tag 3)
    
    public var description: String {
        switch self {
            case .int(let v): return "Int(\(v))"
            case .bigUInt(let d): return "BigUInt(\(d))"
            case .bigNInt(let d): return "BigNInt(-\(d))"
        }
    }
    
    public var intValue : Int64 {
        switch self {
            case .int(let v):
                return v
            case .bigUInt(let bigUInt):
                return Int64(bigUInt)
            case .bigNInt(let bigNInt):
                return Int64(-1*bigNInt)
        }
    }
    
    public var bigUIntValue : BigUInt {
        switch self {
            case .int(let v):
                return BigUInt(v)
            case .bigUInt(let bigUInt):
                return bigUInt
            case .bigNInt(let bigNInt):
                return BigUInt(-1*bigNInt)
        }
    }
    
    public var bigNIntValue : BigInt {
        switch self {
            case .int(let v):
                return BigInt((v))
            case .bigUInt(let bigUInt):
                return BigInt(BigUInt(bigUInt))
            case .bigNInt(let bigNInt):
                return bigNInt
        }
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
                self = .int(Int64(v))
            case .uint(let v):
                self = .int(Int64(v))
            case .cborTag(let tag) where tag.tag == 2:
                guard case let .bytes(bigUInt) = tag.value else {
                    throw CardanoCoreError.deserializeError("Invalid bigUInt CBOR tag value: \(tag.value)")
                }
                self = .bigUInt(try CBORDecoder().decode(
                    BigUInt.self,
                    from: bigUInt
                ))
            case .cborTag(let tag) where tag.tag == 3:
                guard case let .bytes(bigNInt) = tag.value else {
                    throw CardanoCoreError.deserializeError("Invalid bigNInt CBOR tag value: \(tag.value)")
                }
                self = .bigNInt(try CBORDecoder().decode(
                    BigInt.self,
                    from: bigNInt
                ))
            default:
                throw CardanoCoreError.deserializeError("Invalid BigInt type: \(primitive)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .int(let v):
                return .int(Int(v))
            case .bigUInt(let bigUInt):
                return .bigUInt(bigUInt)
            case .bigNInt(let bigNInt):
                return .bigInt(bigNInt)
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ data: OrderedDictionary<Primitive, Primitive>) throws -> BigInteger {
        if case let .int(intData) = data[.string("int")] {
            return .int(Int64(intData))
        } else if case let .uint(intData) = data[.string("int")] {
            return .bigUInt(BigUInt(intData))
        } else if case let .bigInt(intData) = data[.string("int")] {
            return .bigNInt(intData)
        } else if case let .bigUInt(intData) = data[.string("int")] {
            return .bigUInt(intData)
        } else {
            throw CardanoCoreError.deserializeError("Invalid BigInteger dict: \(data)")
        }
    }
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        switch self {
            case .int(let value):
                return [.string("int"): .int(Int(value))]
            case .bigUInt(let value):
                return [.string("int"): .bigUInt(value)]
            case .bigNInt(let value):
                return [.string("int"): .bigInt(value)]
        }
    }
}
