import Foundation
import OrderedCollections
import SwiftKES

/// KES signature size in bytes (Sum6KES depth 6)
public let KES_SIGNATURE_SIZE = 448

// MARK: - SwiftKES.KESSignature Serialization Extensions

/// Extension to make `SwiftKES.KESSignature` conform to `Serializable` for CBOR encoding/decoding.
///
/// KES signature as defined in the Conway CDDL:
/// `kes_signature = bytes .size 448`
extension KESSignature: @retroactive CustomStringConvertible {}
extension KESSignature: @retroactive CustomDebugStringConvertible {}
extension KESSignature: Serializable {

    /// Initialize from a CBOR primitive.
    ///
    /// Assumes Sum6KES (depth 6) since that's what Cardano uses.
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid KESSignature primitive: expected bytes, got \(primitive)"
            )
        }
        guard data.count == KES_SIGNATURE_SIZE else {
            throw CardanoCoreError.deserializeError(
                "Invalid KESSignature size: expected \(KES_SIGNATURE_SIZE), got \(data.count)"
            )
        }
        try self.init(depth: Sum6KES.depth, bytes: data)
    }

    /// Convert to a CBOR primitive.
    public func toPrimitive() -> Primitive {
        return .bytes(self.bytes)
    }

    /// Deserialize from a dictionary representation.
    public static func fromDict(_ primitive: Primitive) throws -> KESSignature {
        switch primitive {
        case .bytes(let data):
            return try KESSignature(depth: Sum6KES.depth, bytes: data)
        case .string(let hexString):
            let data = hexString.hexStringToData
            return try KESSignature(depth: Sum6KES.depth, bytes: data)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid KESSignature dict: expected bytes or string"
            )
        }
    }

    /// Serialize to a dictionary representation.
    public func toDict() throws -> Primitive {
        return .bytes(self.bytes)
    }
}

// MARK: - KESSignature Codable Conformance

extension KESSignature: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.bytes)
    }
}

extension KESSignature: @retroactive Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        try self.init(depth: Sum6KES.depth, bytes: data)
    }
}

// MARK: - SwiftKES.KESSignature Hashable Conformance

extension KESSignature: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.bytes)
        hasher.combine(self.depth)
    }
}
