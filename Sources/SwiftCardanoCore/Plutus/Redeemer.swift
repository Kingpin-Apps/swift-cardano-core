import Foundation
import PotentCBOR
import PotentCodables
import OrderedCollections

/// Redeemer tag, which indicates the type of redeemer.
public enum RedeemerTag: Int, Serializable {
    case spend = 0
    case mint = 1
    case cert = 2
    case reward = 3
    case voting = 4
    case proposing = 5
    
    public init(from primitive: Primitive) throws {
        guard case let .uint(value) = primitive,
              let tag = RedeemerTag(rawValue: Int(value)) else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerTag primitive: \(primitive)")
        }
        self = tag
    }
    
    public func toPrimitive() throws -> Primitive {
        return .int(rawValue)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> RedeemerTag {
        guard case let .int(value) = primitive,
              let tag = RedeemerTag(rawValue: value) else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerTag: \(primitive)")
        }
        return tag
    }
    
    public func toDict() throws -> Primitive {
        return .int(rawValue)
    }
    
    public func description() -> String {
        switch self {
            case .spend: return "spend"
            case .mint: return "mint"
            case .cert: return "cert"
            case .reward: return "reward"
            case .voting: return "voting"
            case .proposing: return "proposing"
        }
    }
}


public enum RedeemerCodingKeys: String, CodingKey {
    case tag
    case index
    case data
    case exUnits
}

public protocol RedeemerProtocol: Serializable {
    var tag: RedeemerTag? { get set }
    var index: Int { get set }
    var data: PlutusData { get set }
    var exUnits: ExecutionUnits? { get set }
    
    init(tag: RedeemerTag?, index: Int, data: PlutusData, exUnits: ExecutionUnits?)
}

extension RedeemerProtocol {
    
    public static func == (lhs: Self, rhs: any RedeemerProtocol) -> Bool {
        return lhs.tag == rhs.tag &&
        lhs.index == rhs.index &&
        lhs.data == rhs.data &&
        lhs.exUnits == rhs.exUnits
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 4 else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer primitive")
        }
        
        let tag = try RedeemerTag(from: primitive[0])
        
        guard case let .uint(index) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer index")
        }
        
        let exUnits = try ExecutionUnits(from: primitive[3])
        let data = try PlutusData.init(from: primitive[2])
        
        self.init(
            tag: tag,
            index: Int(index),
            data: data,
            exUnits: exUnits
        )
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try tag?.toPrimitive() ?? .null,
            .int(index),
            try data.toPrimitive(),
            try exUnits?.toPrimitive() ?? .null
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Self {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer dict")
        }
        var tag: RedeemerTag? = nil
        if let tagPrimitive = dictValue[.string(RedeemerCodingKeys.tag.rawValue)] {
            tag = try RedeemerTag(from: tagPrimitive)
        }
        
        guard let indexPrimitive = dictValue[.string(RedeemerCodingKeys.index.rawValue)],
              case let .int(index) = indexPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid index in Redeemer dict")
        }
        
        guard let dataPrimitive = dictValue[.string(RedeemerCodingKeys.data.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing data in Redeemer dict")
        }
        let data = try PlutusData(from: dataPrimitive)
        
        var exUnits: ExecutionUnits? = nil
        if let exUnitsPrimitive = dictValue[.string(RedeemerCodingKeys.exUnits.rawValue)] {
            exUnits = try ExecutionUnits(from: exUnitsPrimitive)
        }
        
        return Self(
            tag: tag,
            index: index,
            data: data,
            exUnits: exUnits
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedCollections.OrderedDictionary<Primitive, Primitive>()
        if let tag = tag {
            dict[.string(RedeemerCodingKeys.tag.rawValue)] = try tag.toPrimitive()
        }
        dict[.string(RedeemerCodingKeys.index.rawValue)] = .int(index)
        dict[.string(RedeemerCodingKeys.data.rawValue)] = try data.toPrimitive()
        if let exUnits = exUnits {
            dict[.string(RedeemerCodingKeys.exUnits.rawValue)] = try exUnits.toPrimitive()
        }
        return .orderedDict(dict)
    }
}

public struct Redeemer: RedeemerProtocol {
    public var tag: RedeemerTag?
    public var index: Int = 0
    public var data: PlutusData
    public var exUnits: ExecutionUnits?

    public init(tag: RedeemerTag? = nil,
                index: Int = 0,
                data: PlutusData,
                exUnits: ExecutionUnits? = nil) {
        self.tag = tag
        self.index = index
        self.data = data
        self.exUnits = exUnits
    }
}

/// Represents a unique key for a Redeemer.
public struct RedeemerKey: Serializable {
    public var tag: RedeemerTag
    public var index: Int = 0

    public init(tag: RedeemerTag, index: Int = 0) {
        self.tag = tag
        self.index = index
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        tag = try container.decode(RedeemerTag.self)
        index = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(tag)
        try container.encode(index)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(index)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2,
              case let .int(index) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerKey primitive")
        }
        
        let tag = try RedeemerTag(from: primitive[0])
        
        self.tag = tag
        self.index = index
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try tag.toPrimitive(),
            .int(index)
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> RedeemerKey {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .int(index) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerKey dict: \(primitive)")
        }
        
        let tag = try RedeemerTag.fromDict(elements[0])
        return RedeemerKey(tag: tag, index: index)
    }
    
    public func toDict() throws -> Primitive {
        return .list([
            try tag.toDict(),
            .int(index)
        ])
    }
}

/// Represents the value of a Redeemer, including data and execution units.
public struct RedeemerValue: Serializable {
    public var data: PlutusData
    public var exUnits: ExecutionUnits

    public init(data: PlutusData, exUnits: ExecutionUnits) {
        self.data = data
        self.exUnits = exUnits
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        data = try container.decode(PlutusData.self)
        exUnits = try container.decode(ExecutionUnits.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(data)
        try container.encode(exUnits)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerValue primitive")
        }
        
        let data = try PlutusData.init(from: primitive[2])
        let exUnits = try ExecutionUnits(from: primitive[1])
        
        self.data = data
        self.exUnits = exUnits
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try Primitive.fromAny(data),
            try exUnits.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> RedeemerValue {
        guard case let .list(elements) = primitive,
              elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerValue dict: \(primitive)")
        }
        
        let data = try PlutusData(from: elements[0])
        let exUnits = try ExecutionUnits.fromDict(elements[1])
        return RedeemerValue(data: data, exUnits: exUnits)
    }
    
    public func toDict() throws -> Primitive {
        return .list([
            try data.toDict(),
            try exUnits.toDict()
        ])
    }
}

/// Represents a mapping of RedeemerKeys to RedeemerValues.
public struct RedeemerMap: Serializable {
    private var storage: [RedeemerKey: RedeemerValue]

    public init() {
        self.storage = [:]
    }

    public init(_ map: [RedeemerKey: RedeemerValue]) {
        self.storage = map
    }
    
    public init(uniqueKeysWithValues elements: [(RedeemerKey, RedeemerValue)]) {
        self.storage = [:]
        for (key, value) in elements {
            storage[key] = value
        }
    }

    public subscript(key: RedeemerKey) -> RedeemerValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    public var dictionary: [RedeemerKey: RedeemerValue] {
        return storage
    }
    
    public var isEmpty: Bool {
        return storage.isEmpty
    }
    
    public var count: Int {
        return storage.count
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let cborMap = CBOR.map(OrderedDictionary(
            uniqueKeysWithValues: try storage.map { (key, value) in
                let cborKey = try key.toCBORData().toCBOR
                let cborValue = try value.toCBORData().toCBOR
                return (cborKey, cborValue)
            })
        )
        try container.encode(cborMap)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cbor = try container.decode(CBOR.self)
        guard case let .map(cborMap) = cbor else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerMap type")
        }
        
        storage = [:]
        for (key, value) in cborMap {
            let keyData = try CBORSerialization.data(from: key)
            let valueData = try CBORSerialization.data(from: value)
            let redeemerKey = try RedeemerKey.fromCBOR(data: keyData)
            let redeemerValue = try RedeemerValue.fromCBOR(data: valueData)
            storage[redeemerKey] = redeemerValue
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }

    public static func == (lhs: RedeemerMap, rhs: RedeemerMap) -> Bool {
        lhs.storage == rhs.storage
    }
    
    public init(from primitive: Primitive) throws {
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid RedeemerMap primitive: \(primitive)")
        }
        
        storage = [:]
        for (keyPrimitive, valuePrimitive) in primitiveDict {
            let key = try RedeemerKey(from: keyPrimitive)
            let value = try RedeemerValue(from: valuePrimitive)
            storage[key] = value
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]
        
        for (key, value) in storage {
            let keyPrimitive = try key.toPrimitive()
            let valuePrimitive = try value.toPrimitive()
            dict[keyPrimitive] = valuePrimitive
        }
        
        return .dict(dict)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> RedeemerMap {
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
        case let .dict(dict):
            primitiveDict.merge(dict) { (_, new) in new }
        case let .orderedDict(orderedDict):
            primitiveDict = orderedDict
        default:
            throw CardanoCoreError.deserializeError("Invalid RedeemerMap dict: \(primitive)")
        }
        
        var storage: [RedeemerKey: RedeemerValue] = [:]
        for (keyPrimitive, valuePrimitive) in primitiveDict {
            let key = try RedeemerKey.fromDict(keyPrimitive)
            let value = try RedeemerValue.fromDict(valuePrimitive)
            storage[key] = value
        }
        
        return RedeemerMap(storage)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        
        for (key, value) in storage {
            let keyPrimitive = try key.toDict()
            let valuePrimitive = try value.toDict()
            // For JSON, convert array keys to strings
            let keyString = "[\(try keyPrimitive.toJSON())]"
            dict[.string(keyString)] = valuePrimitive
        }
        
        return .orderedDict(dict)
    }
}

/// Redeemers can be a list of Redeemer objects or a map of Redeemer keys to values.
public enum Redeemers: Serializable {
    case list([Redeemer])
    case map(RedeemerMap)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let cbor = try? container.decode(CBOR.self)
        
        if case let .array(cborArray) = cbor {
            self = .list(
                try cborArray
                    .compactMap { try Redeemer.fromCBOR(
                        data: try CBORSerialization.data(from: $0)
                    )
                    })
        } else if case let.map(cborMap) = cbor {
            let map = OrderedDictionary(
                uniqueKeysWithValues: try cborMap.map {
                    (try RedeemerKey
                            .fromCBOR(
                                data: try CBORSerialization.data(from: $0.key)
                            ),
                        try RedeemerValue
                            .fromCBOR(
                                data: try CBORSerialization.data(from: $0.value)
                            )
                    )
                }
            )
            self = .map(RedeemerMap(
                uniqueKeysWithValues: map.map(
                    { (key, value) in
                        (key, value)
                    }
                ))
            )
        } else {
            throw CardanoCoreError.deserializeError("Invalid Redeemers type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .list(let redeemers):
                try container.encode(redeemers)
            case .map(let redeemerMap):
                try container.encode(redeemerMap)
        }
    }
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .list(let list):
                var redeemers: [Redeemer] = []
                for item in list {
                    let redeemer = try Redeemer(from: item)
                    redeemers.append(redeemer)
                }
                self = .list(redeemers)
                
            case .dict(_):
                let redeemerMap = try RedeemerMap(from: primitive)
                self = .map(redeemerMap)
                
            case .orderedDict(_):
                let redeemerMap = try RedeemerMap(from: primitive)
                self = .map(redeemerMap)
                
            default:
                throw CardanoCoreError.deserializeError("Invalid Redeemers primitive")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .list(let redeemers):
                return .list(try redeemers.map { try $0.toPrimitive() })
            case .map(let redeemerMap):
                return try redeemerMap.toPrimitive()
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> Redeemers {
        switch primitive {
        case .list(let list):
            var redeemers: [Redeemer] = []
            for item in list {
                let redeemer = try Redeemer.fromDict(item)
                redeemers.append(redeemer)
            }
            return .list(redeemers)
            
        case .dict(_), .orderedDict(_):
            let redeemerMap = try RedeemerMap.fromDict(primitive)
            return .map(redeemerMap)
            
        default:
            throw CardanoCoreError.deserializeError("Invalid Redeemers dict: \(primitive)")
        }
    }
    
    public func toDict() throws -> Primitive {
        switch self {
        case .list(let redeemers):
            return .list(try redeemers.map { try $0.toDict() })
        case .map(let redeemerMap):
            return try redeemerMap.toDict()
        }
    }
}
