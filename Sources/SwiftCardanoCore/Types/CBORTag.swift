import Foundation
import PotentCBOR
import OrderedCollections

public protocol CBORTaggable: Serializable, Sendable {
    var tag: UInt64 { get }
    var value: Primitive { get set }

    init(tag: UInt64, value: Primitive) throws
}

extension CBORTaggable {
    public func taggedCBOR() -> CBOR {
        let cborData = try! CBOREncoder().encode(value).toCBOR
        return .tagged(
            CBOR.Tag(rawValue: tag),
            cborData
        )
    }

    public func fromCBOR(_ cbor: CBOR) throws -> Self {
        guard case let .tagged(tag, value) = cbor else {
            throw CardanoCoreError.valueError("CBOR value is not tagged")
        }
        return try Self(
            tag: tag.rawValue,
            value: try value.toPrimitive()
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            let tag = tag.rawValue
//            let value = try AnyValue.wrapped(cborData.unwrapped)
            try self.init(tag: tag, value: cborData.toPrimitive())
        } else {
            throw CardanoCoreError.valueError("CBORTag must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(taggedCBOR())
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(tagged) = primitive else {
            throw CardanoCoreError.valueError("Invalid CBORTag type")
        }
        
        try self.init(tag: tagged.tag, value: tagged.value)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .cborTag(CBORTag(tag: tag, value: value))
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Self {
        guard case let .orderedDict(dictValue) = dict,
              case let .int(tag) = dictValue[.string("tag")],
              case let valuePrimitive = dictValue[.string("value")] else {
            throw CardanoCoreError.valueError("Invalid CBORTag dictionary: \(dict)")
        }
        
        return try Self(
            tag: UInt64(tag),
            value: valuePrimitive!
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("tag")] = .uint(UInt(tag))
        // The value is already a Primitive - just use it directly
        // It should already have string keys if it was created via toDict()
        dict[.string("value")] = value
        return .orderedDict(dict)
    }
}

public struct CBORTag: CBORTaggable {
    public var tag: UInt64
    public var value: Primitive

    public init(tag: UInt64, value: Primitive) {
        self.tag = tag
        self.value = value
    }
}
