import Foundation
import CBORCodable
import OrderedCollections

/// A value wrapped in a CBOR tag (major type 6).
///
/// Conforming types are written as `#6.<tag>(value)`. The protocol extension supplies the CBOR, `Codable` and dictionary conversions, so a conforming type only stores ``tag`` and ``value`` and provides ``init(tag:value:)``.
public protocol CBORTaggable: Serializable, Sendable {
    /// The CBOR tag number.
    var tag: UInt64 { get }
    /// The tagged content.
    var value: Primitive { get set }

    /// Creates the tagged value from a tag number and its content.
    ///
    /// - Parameters:
    ///   - tag: The CBOR tag number.
    ///   - value: The tagged content.
    /// - Throws: When a conforming type does not accept the tag or the content.
    init(tag: UInt64, value: Primitive) throws
}

extension CBORTaggable {
    /// This value as a tagged CBOR item, `#6.<tag>(value)`.
    ///
    /// - Returns: The tagged CBOR item.
    /// - Throws: When ``value`` cannot be converted to CBOR, such as a map
    ///   whose keys repeat once written as CBOR.
    public func taggedCBOR() throws -> CBOR {
        let cborData = try value.toCBOR()
        return .tagged(
            UInt64(tag),
            cborData
        )
    }

    /// Reads a value of this type from a tagged CBOR item.
    ///
    /// - Parameter cbor: A `.tagged` CBOR item.
    /// - Returns: A new value built from the item's tag and content.
    /// - Throws: When `cbor` is not tagged, or ``init(tag:value:)`` rejects it.
    public func fromCBOR(_ cbor: CBOR) throws -> Self {
        guard case let .tagged(tag, value) = cbor else {
            throw CardanoCoreError.valueError("CBOR value is not tagged")
        }
        return try Self(
            tag: tag,
            value: try value.toPrimitive()
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            let tag = tag
//            let value = try AnyValue.wrapped(cborData.unwrapped)
            try self.init(tag: tag, value: cborData.toPrimitive())
        } else {
            throw CardanoCoreError.valueError("CBORTag must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try taggedCBOR())
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
              let tag = dictValue[.string("tag")],
              let valuePrimitive = dictValue[.string("value")] else {
            throw CardanoCoreError.valueError("Invalid CBORTag dictionary: \(dict)")
        }

        return try Self(tag: try tag.integer("CBOR tag"), value: valuePrimitive)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("tag")] = .uint(UInt64(tag))
        // The value is already a Primitive - just use it directly
        // It should already have string keys if it was created via toDict()
        dict[.string("value")] = value
        return .orderedDict(dict)
    }
}

/// A CBOR tag with any tag number and any content.
public struct CBORTag: CBORTaggable {
    /// The CBOR tag number.
    public var tag: UInt64
    /// The tagged content.
    public var value: Primitive

    /// Creates a tagged value.
    ///
    /// - Parameters:
    ///   - tag: The CBOR tag number.
    ///   - value: The tagged content.
    public init(tag: UInt64, value: Primitive) {
        self.tag = tag
        self.value = value
    }
}
