import Foundation
import PotentCBOR
import PotentCodables
import OrderedCollections

public indirect enum Primitive: CBORSerializable, Equatable, Hashable {
    case bytes(Data)
    case byteArray([UInt8])
    case string(String)
    case int(Int)
    case float(Double)
    case decimal(Decimal)
    case bool(Bool)
    case tuple(AnyTuple)
    case list([Primitive])
    case indefiniteList(IndefiniteList<Primitive>)
    case dict([Primitive: Primitive])
    case orderedDict(OrderedDictionary<Primitive, Primitive>)
    case datetime(Date)
    case regex(NSRegularExpression)
    case cborSimpleValue(CBOR)
    case cborTag(CBORTag)
    case orderedSet(OrderedSet<Primitive>)
    case nonEmptyOrderedSet(NonEmptyOrderedSet<Primitive>)
    case unitInterval(UnitInterval)
    case frozenSet(Set<Primitive>)
    case frozenDict([Primitive: Primitive])
    case frozenList([Primitive])
    case indefiniteFrozenList(IndefiniteList<Primitive>)
    case byteString(ByteString)
    case plutusData(PlutusData)
    case null
    
    /// Convert an arbitrary value to a Primitive.
    public static func fromAny(_ value: Any) throws -> Primitive {
        switch value {
        case let v as Primitive:
            return v
        case let v as Int:
            return .int(v)
        case let v as UInt8:
            return .int(Int(v))
        case let v as UInt:
            return .int(Int(v))
        case let v as Int8:
            return .int(Int(v))
        case let v as Int16:
            return .int(Int(v))
        case let v as Int32:
            return .int(Int(v))
        case let v as Int64:
            return .int(Int(v))
        case let v as UInt16:
            return .int(Int(v))
        case let v as UInt32:
            return .int(Int(v))
        case let v as UInt64:
            return .int(Int(v))
        case let v as Double:
            return .float(v)
        case let v as Float:
            return .float(Double(v))
        case let v as Decimal:
            return .decimal(v)
        case let v as Bool:
            return .bool(v)
        case let v as String:
            return .string(v)
        case let v as Data:
            return .bytes(v)
        case let v as [UInt8]:
            return .byteArray(v)
        case let v as [Any]:
            return .list(try v.map { try Primitive.fromAny($0) })
        case let v as OrderedDictionary<AnyHashable, Any>:
            var dict: OrderedDictionary<Primitive, Primitive> = [:]
            for (key, value) in v {
                let keyPrimitive = try Primitive.fromAny(key)
                let valuePrimitive = try Primitive.fromAny(value)
                dict[keyPrimitive] = valuePrimitive
            }
            return .orderedDict(dict)
        case let v as [AnyHashable: Any]:
            var dict: [Primitive: Primitive] = [:]
            for (key, value) in v {
                let keyPrimitive = try Primitive.fromAny(key)
                let valuePrimitive = try Primitive.fromAny(value)
                dict[keyPrimitive] = valuePrimitive
            }
            return .dict(dict)
        case let v as Date:
            return .datetime(v)
        case let v as NSRegularExpression:
            return .regex(v)
        case let v as ByteString:
            return .byteString(v)
        case let v as UnitInterval:
            return .unitInterval(v)
        case let v as CBORTag:
            return .cborTag(v)
        case let v as OrderedSet<Primitive>:
            return .orderedSet(v)
        case let v as NonEmptyOrderedSet<Primitive>:
            return .nonEmptyOrderedSet(v)
        case let v as CBOR:
            return .cborSimpleValue(v)
        case let v as PlutusData:
            return .plutusData(v)
        case Optional<Any>.none:
            return .null
        default:
            throw CardanoCoreError.typeError("Cannot convert type \(type(of: value)) to Primitive")
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cbor = try container.decode(CBOR.self)
        self = try Primitive.from(cbor: cbor)
    }
    
    private static func from(cbor: CBOR) throws -> Primitive {
        switch cbor {
            case .byteString(let data):
                return .bytes(data)
            case .utf8String(let string):
                return .string(string)
            case .unsignedInt(let value):
                return .int(Int(value))
            case .negativeInt(let value):
                return .int(Int(bitPattern: ~UInt(value)))
            case .float(let value):
                return .float(Double(value))
            case .double(let value):
                return .float(value)
            case .boolean(let value):
                return .bool(value)
            case .null:
                return .null
            case .array(let array):
                let primitives = try array.map { try Primitive.from(cbor: $0) }
                return .list(primitives)
            case .indefiniteArray(let array):
                let primitives = try array.map { try Primitive.from(cbor: $0) }
                return .indefiniteList(IndefiniteList(primitives))
            case .map(let map):
                var dict: [Primitive: Primitive] = [:]
                for (key, value) in map {
                    dict[try Primitive.from(cbor: key)] = try Primitive.from(cbor: value)
                }
//                return .dict(dict)
                return .orderedDict(OrderedDictionary<Primitive, Primitive>(
                    uniqueKeysWithValues: try map.elements
                        .map {
                            (
                                try Primitive.from(cbor: $0.key),
                                try Primitive.from(cbor: $0.value)
                            )
                        }
                    )
                )
            case .indefiniteMap(let map):
                var dict: [Primitive: Primitive] = [:]
                for (key, value) in map {
                    dict[try Primitive.from(cbor: key)] = try Primitive.from(cbor: value)
                }
                return .dict(dict)
            case .simple(let simple):
                return .cborSimpleValue(.simple(simple))
            case .tagged(let tag, let value):
                if tag.rawValue == UInt64(UnitInterval.tag) {
                    // Handle both Int and UInt64 types for fraction components
                    let numerator: Int
                    let denominator: Int
                    
                    if let numValue = value.arrayValue![0].unwrapped as? Int {
                        numerator = numValue
                    } else if let numValue = value.arrayValue![0].unwrapped as? UInt64 {
                        numerator = Int(numValue)
                    } else if let numValue = value.arrayValue![0].unwrapped as? Int64 {
                        numerator = Int(numValue)
                    } else {
                        throw CardanoCoreError.valueError("Invalid fraction numerator type: \(type(of: value.arrayValue![0].unwrapped))")
                    }
                    
                    if let denValue = value.arrayValue![1].unwrapped as? Int {
                        denominator = denValue
                    } else if let denValue = value.arrayValue![1].unwrapped as? UInt64 {
                        denominator = Int(denValue)
                    } else if let denValue = value.arrayValue![1].unwrapped as? Int64 {
                        denominator = Int(denValue)
                    } else {
                        throw CardanoCoreError.valueError("Invalid fraction denominator type: \(type(of: value.arrayValue![1].unwrapped))")
                    }
                    
                    let unitInterval = UnitInterval(
                        numerator: UInt64(numerator),
                        denominator: UInt64(denominator)
                    )
                    return .unitInterval(unitInterval)
                } else if tag == CBOR.Tag.iso8601DateTime {
                    guard let date = value.unwrapped else {
                        throw CardanoCoreError.valueError("Invalid date format")
                    }
                    return .datetime(
                        Date(timeIntervalSince1970: date as! TimeInterval)
                    )
                } else if tag == CBOR.Tag.epochDateTime {
                    guard let date = value.unwrapped else {
                        throw CardanoCoreError.valueError("Invalid date format")
                    }
                    return .datetime(
                        Date(timeIntervalSince1970: date as! TimeInterval)
                    )
                }
                
                let wrapped = CBORTag(
                    tag: tag.rawValue,
//                    value: try AnyValue.wrapped(value.unwrapped)
                    value: try value.toPrimitive().toAnyValue()
                )
                return .cborTag(wrapped)
            case .indefiniteByteString(let string):
                return .bytes(string)
            case .indefiniteUtf8String(let string):
                return .string(string)
            case .undefined:
                return .null
            case .half(let value):
                return .float(Double(value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toCBOR())
    }
    
    public func toCBOR() throws -> CBOR {
        switch self {
            case .bytes(let data):
                return .byteString(data)
            case .byteArray(let array):
                return .byteString(Data(array))
            case .string(let string):
                return .utf8String(string)
            case .int(let value):
                return value >= 0 ? .unsignedInt(UInt64(value)) : .negativeInt(~UInt64(bitPattern: Int64(value)))
            case .float(let value):
                return .double(value)
            case .decimal(let decimal):
                return .utf8String(decimal.description)
            case .bool(let value):
                return .boolean(value)
            case .tuple(let tup):
                return .array(try tup.elements.map { try $0.toCBOR() })
            case .list(let list):
                return .array(try list.map { try $0.toCBOR() })
            case .indefiniteList(let list):
                return .indefiniteArray(try list.getAll().map { try $0.toCBOR() })
            case .dict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .orderedDict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .datetime(let date):
                return try CBOREncoder().encode(date).toCBOR
            case .regex(let regex):
                return .utf8String(regex.pattern)
            case .cborSimpleValue(let simple):
                return simple
            case .cborTag(let tag):
                return .tagged(
                    CBOR.Tag(rawValue: tag.tag),
                    try CBOREncoder().encode(tag.value).toCBOR
                )
            case .orderedSet(let set):
                return try set.toCBOR()
            case .nonEmptyOrderedSet(let set):
                return try set.toCBOR()
            case .unitInterval(let unitInterval):
                return .tagged(CBOR.Tag(rawValue: UInt64(UnitInterval.tag)), .array([
                    .unsignedInt(UInt64(unitInterval.numerator)),
                    .unsignedInt(UInt64(unitInterval.denominator))
                ]))
            case .frozenSet(let set):
                return .array(try set.map { try $0.toCBOR() })
            case .frozenDict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .frozenList(let list):
                return .array(try list.map { try $0.toCBOR() })
            case .indefiniteFrozenList(let list):
                return .indefiniteArray(try list.getAll().map { try $0.toCBOR() })
            case .byteString(let byteString):
                return .byteString(byteString.value)
            case .plutusData(let plutusData):
                return try plutusData.toCBORData().toCBOR
            case .null:
                return CBOR.null
        }
    }
    
    public static func == (lhs: Primitive, rhs: Primitive) -> Bool {
        switch (lhs, rhs) {
            case (.bytes(let a), .bytes(let b)):
                return a == b
            case (.byteArray(let a), .byteArray(let b)):
                return a == b
            case (.string(let a), .string(let b)):
                return a == b
            case (.int(let a), .int(let b)):
                return a == b
            case (.float(let a), .float(let b)):
                return a == b
            case (.decimal(let a), .decimal(let b)):
                return a == b
            case (.bool(let a), .bool(let b)):
                return a == b
            case (.tuple(let a), .tuple(let b)):
                return a == b
            case (.list(let a), .list(let b)):
                return a == b
            case (.indefiniteList(let a), .indefiniteList(let b)):
                return a == b
            case (.dict(let a), .dict(let b)):
                return a == b
            case (.orderedDict(let a), .orderedDict(let b)):
                return a == b
            case (.datetime(let a), .datetime(let b)):
                return a == b
            case (.regex(let a), .regex(let b)):
                return a.pattern == b.pattern // NSRegularExpression compare patterns
            case (.cborSimpleValue(let a), .cborSimpleValue(let b)):
                return a == b
            case (.cborTag(let a), .cborTag(let b)):
                return a == b
            case (.orderedSet(let a), .orderedSet(let b)):
                return a == b
            case (.nonEmptyOrderedSet(let a), .nonEmptyOrderedSet(let b)):
                return a == b
            case (.unitInterval(let a), .unitInterval(let b)):
                return a == b
            case (.frozenSet(let a), .frozenSet(let b)):
                return a == b
            case (.frozenDict(let a), .frozenDict(let b)):
                return a == b
            case (.frozenList(let a), .frozenList(let b)):
                return a == b
            case (.indefiniteFrozenList(let a), .indefiniteFrozenList(let b)):
                return a == b
            case (.byteString(let a), .byteString(let b)):
                return a == b
            default:
                return false
        }
    }
    
    /// Converts this Primitive back to AnyValue, reversing the toPrimitives() mapping.
    public func toAnyValue() -> AnyValue {
        switch self {
            case .null:
                return .nil
            case .bool(let bool):
                return .bool(bool)
            case .string(let string):
                return .string(string)
            case .int(let intVal):
                return .int64(Int64(intVal))
            case .float(let floatVal):
                return .double(floatVal)
            case .decimal(let decimalVal):
                return .decimal(decimalVal)
            case .bytes(let data):
                return .data(data)
            case .byteArray(let array):
                return .data(Data(array))
            case .datetime(let date):
                return .date(date)
            case .tuple(let tup):
                // Explicitly cast each element to help with type inference
                let anyValues: [AnyValue] = tup.elements.map { element -> AnyValue in
                    return element.toAnyValue()
                }
                return .array(anyValues)
            case .list(let list):
                return .array(list.map { $0.toAnyValue() })
            case .indefiniteList(let list):
                return .indefiniteArray(list.map { $0.toAnyValue() })
            case .dict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .orderedDict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .regex(let regex):
                return .string(regex.pattern)
            case .cborSimpleValue(let cbor):
                return try! AnyValue.wrapped(cbor)
            case .cborTag(let tag):
                return tag.value
            case .orderedSet(let set):
                return .array(set.elements.map { $0.toAnyValue() })
            case .nonEmptyOrderedSet(let set):
                return .array(set.elements.map { $0.toAnyValue() })
            case .unitInterval(let unitInterval):
                return .array(
                    [
                        .int(Int(unitInterval.numerator)),
                        .int(Int(unitInterval.denominator))
                    ]
                )
            case .frozenSet(let set):
                return .array(set.map { $0.toAnyValue() })
            case .frozenDict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .frozenList(let list):
                return .array(list.map { $0.toAnyValue() })
            case .indefiniteFrozenList(let list):
                return .indefiniteArray(list.map { $0.toAnyValue() })
            case .byteString(let byteString):
                return .data(byteString.value)
            case .plutusData(let plutus):
                return try! AnyValue.wrapped(plutus)
        }
    }
    
    public init(from primitive: Primitive) throws {
        self = primitive
    }

    public func toPrimitive() throws -> Primitive {
        return self
    }
}
