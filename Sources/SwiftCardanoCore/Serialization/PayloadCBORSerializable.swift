import Foundation

public protocol PayloadCBORSerializable: TextEnvelopable {}

public extension PayloadCBORSerializable where Self: Codable {
    
    /// Deserialize from CBOR.
    /// - Parameter decoder: The decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        try self.init(payload: payload)
    }
    
    /// Serialize to CBOR.
    /// - Parameter encoder: The encoder.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }
    
    func toPrimitive() -> Primitive {
        return .bytes(payload)
    }
    
    init(from primitive: Primitive) throws {
        guard case let .bytes(payload) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid payload for \(Self.self): expected bytes but got \(primitive) type")
        }
        try self.init(payload: payload)
    }
}
