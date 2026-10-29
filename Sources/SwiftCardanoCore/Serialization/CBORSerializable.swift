import Foundation
import CBORCodable

public protocol CBORSerializable: Codable, Equatable, Hashable {
    init(from primitive: Primitive) throws
    func toPrimitive() throws -> Primitive
    func toCBORData(deterministic: Bool) throws -> Data
    func toCBORHex(deterministic: Bool) throws -> String
    static func fromCBOR(data: Data) throws -> Self
    /// Whether ``init(from:)`` is given the primitive as it was written —
    /// indefinite-length byte strings, text strings and maps kept as such —
    /// rather than the form most types read.
    ///
    /// A type that sets this re-encodes to the bytes it was read from, and
    /// passes ``Primitive/normalized()`` to any part of it that does not.
    static var preservesEncoding: Bool { get }
}

extension CBORSerializable {
    public static var preservesEncoding: Bool { false }

    public init(from decoder: Decoder) throws {
        let primitive = try Primitive.decode(
            from: decoder, preservingEncoding: Self.preservesEncoding)
        try self.init(from: primitive)
    }
    
    public init(from cbor: Data) throws {
        self = try CBORDecoder.ledger().decode(Self.self, from: cbor)
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toPrimitive())
    }
    
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        // Cardano's notion of "deterministic" CBOR (CIP-21) is NOT the same
        // as RFC 8949 §4.2 — Cardano preserves indefinite-length arrays for
        // PlutusData list semantics, while §4.2 collapses them. Leaving
        // CBORCodable's deterministic flag off lets indefinite-length items
        // round-trip; map-key ordering is the caller's responsibility for
        // now. A Cardano-specific deterministic mode can layer on top
        // later.
        _ = deterministic
        let cborEncoder = CBOREncoder()
        return try cborEncoder.encode(self)
    }
    
    public func toCBORHex(deterministic: Bool = false) throws -> String {
        return try toCBORData(deterministic: deterministic).toHex
    }
    
    public static func fromCBOR(data: Data) throws -> Self {
        return try CBORDecoder.ledger().decode(Self.self, from: data)
    }
    
    public static func fromCBORHex(_ hexString: String) throws -> Self {
        guard let data = Data(hexString: hexString) else {
            throw CardanoCoreError.invalidArgument("Invalid hex string: \(hexString)")
        }
        return try fromCBOR(data: data)
    }

}
