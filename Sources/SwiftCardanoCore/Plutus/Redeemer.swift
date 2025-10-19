import Foundation
import PotentCBOR
import PotentCodables
import OrderedCollections

/// Redeemer tag, which indicates the type of redeemer.
public enum RedeemerTag: Int, CBORSerializable {
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


public class Redeemer: CBORSerializable, Equatable, Hashable {
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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(index)
        hasher.combine(data)
        hasher.combine(exUnits)
    }

    public static func == (lhs: Redeemer, rhs: Redeemer) -> Bool {
        return lhs.tag == rhs.tag &&
            lhs.index == rhs.index &&
            lhs.data == rhs.data &&
            lhs.exUnits == rhs.exUnits
    }
    
    required public init(from primitive: Primitive) throws {
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
        
        self.tag = tag
        self.index = Int(index)
        self.data = data
        self.exUnits = exUnits
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try tag?.toPrimitive() ?? .null,
            .int(index),
            try data.toPrimitive(),
            try exUnits?.toPrimitive() ?? .null
        ])
    }
}

/// Represents a unique key for a Redeemer.
public struct RedeemerKey: CBORSerializable, Equatable, Hashable {
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
}

/// Represents the value of a Redeemer, including data and execution units.
public struct RedeemerValue: CBORSerializable, Equatable, Hashable {
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
}

/// Represents a mapping of RedeemerKeys to RedeemerValues.
public struct RedeemerMap: CBORSerializable, Equatable, Hashable {
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
}

/// Redeemers can be a list of Redeemer objects or a map of Redeemer keys to values.
public enum Redeemers: CBORSerializable, Equatable, Hashable {
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
}
