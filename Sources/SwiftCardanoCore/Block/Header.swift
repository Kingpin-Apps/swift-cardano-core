import Foundation
import OrderedCollections

/// Block header as defined in the Conway CDDL:
/// `header = [header_body, body_signature : kes_signature]`
///
/// Serialized as a CBOR array with 2 elements.
public struct Header: Serializable {
    /// The header body containing block metadata
    public var headerBody: HeaderBody
    /// KES signature over the header body (448 bytes)
    public var bodySignature: KESSignature

    enum CodingKeys: String, CodingKey {
        case headerBody
        case bodySignature
    }

    public init(headerBody: HeaderBody, bodySignature: KESSignature) {
        self.headerBody = headerBody
        self.bodySignature = bodySignature
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Header primitive: expected list")
        }

        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Header requires exactly 2 elements, got \(elements.count)"
            )
        }

        self.headerBody = try HeaderBody(from: elements[0])
        self.bodySignature = try KESSignature(from: elements[1])
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try headerBody.toPrimitive(),
            bodySignature.toPrimitive()
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> Header {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Header dict")
        }

        guard let headerBodyPrimitive = dict[.string(CodingKeys.headerBody.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing headerBody in Header")
        }
        let headerBody = try HeaderBody.fromDict(headerBodyPrimitive)

        guard let bodySignaturePrimitive = dict[.string(CodingKeys.bodySignature.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing bodySignature in Header")
        }
        let bodySignature = try KESSignature.fromDict(bodySignaturePrimitive)

        return Header(headerBody: headerBody, bodySignature: bodySignature)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.headerBody.rawValue)] = try headerBody.toDict()
        dict[.string(CodingKeys.bodySignature.rawValue)] = try bodySignature.toDict()
        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: Header, rhs: Header) -> Bool {
        return lhs.headerBody == rhs.headerBody &&
            lhs.bodySignature == rhs.bodySignature
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(headerBody)
        hasher.combine(bodySignature)
    }
}
