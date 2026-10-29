import Foundation
import CBORCodable
import OrderedCollections
import SwiftKES
import SwiftNaCl

/// Block header as defined in the Conway CDDL:
/// `header = [header_body, body_signature : kes_signature]`
///
/// Serialized as a CBOR array with 2 elements.
public struct Header: Serializable {
    /// The header body containing block metadata
    public var headerBody: HeaderBody { didSet { originalCBOR = nil } }
    /// KES signature over the header body (448 bytes)
    public var bodySignature: SwiftKES.KESSignature { didSet { originalCBOR = nil } }

    /// The exact bytes this header was decoded from, while it is unchanged.
    ///
    /// A block's hash is the hash of its header as written, so while this is
    /// set ``toCBORData(deterministic:)`` returns these bytes and ``hash()``
    /// hashes them.
    public internal(set) var originalCBOR: Data? = nil

    enum CodingKeys: String, CodingKey {
        case headerBody
        case bodySignature
    }

    public init(headerBody: HeaderBody, bodySignature: SwiftKES.KESSignature) {
        self.headerBody = headerBody
        self.bodySignature = bodySignature
    }

    /// Decodes a header, keeping the bytes it was read from.
    public static func fromCBOR(data: Data) throws -> Header {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after Header")
        }
        var header = try CBORDecoder().decode(Header.self, from: data)
        header.originalCBOR = scanner.bytes
        return header
    }

    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// The bytes this header was decoded from while it is unchanged, otherwise
    /// a fresh encoding.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        return try originalCBOR ?? CBOREncoder().encode(self)
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        // Bytes kept as written, from this type's own `toPrimitive()`: read
        // them again, keeping them.
        if case .cborSimpleValue(.encoded(let bytes)) = primitive {
            self = try Self.fromCBOR(data: bytes)
            return
        }
        guard let elements = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid Header primitive: expected list")
        }

        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Header requires exactly 2 elements, got \(elements.count)"
            )
        }

        self.headerBody = try HeaderBody(from: elements[0])
        self.bodySignature = try SwiftKES.KESSignature(from: elements[1])
    }

    /// The bytes this header was decoded from while it is unchanged — so
    /// that encoding it, alone or inside another value, gives what was
    /// written — otherwise its fields.
    public func toPrimitive() throws -> Primitive {
        if let originalCBOR {
            return .cborSimpleValue(.encoded(originalCBOR))
        }
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
        let bodySignature = try SwiftKES.KESSignature.fromDict(bodySignaturePrimitive)

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

    /// Hashes what `==` compares, leaving out the bytes it was read from.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(headerBody)
    }

    /// The block hash: Blake2b-256 of this header as written while it is
    /// unchanged, otherwise of its encoding.
    ///
    /// - Throws: When it has changed and cannot be encoded.
    public func hash() throws -> Data {
        return try Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: BLOCK_HEADER_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
