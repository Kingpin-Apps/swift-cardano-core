import Foundation
import PotentCBOR
import PotentCodables

public protocol CBORTaggable: CBORSerializable {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(tagged) = primitive else {
            throw CardanoCoreError.valueError("Invalid CBORTag type")
        }
        
        try self.init(tag: tagged.tag, value: tagged.value)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .cborTag(CBORTag(tag: tag, value: value))
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
