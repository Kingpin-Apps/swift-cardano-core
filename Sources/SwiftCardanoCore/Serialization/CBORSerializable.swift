import Foundation
import CBORCodable

/// A value that reads from and writes to CBOR, the binary encoding the
/// Cardano ledger uses.
///
/// A conforming type converts itself to and from a ``Primitive``, a tree of
/// CBOR items; the protocol's extension turns that tree into bytes and back,
/// and supplies the `Codable` conformance through it.
public protocol CBORSerializable: Codable, Equatable, Hashable {
    /// Creates a value from its CBOR primitive form.
    /// - Parameter primitive: The decoded CBOR item.
    /// - Throws: `CardanoCoreError` when the primitive does not have the
    ///   shape this type expects.
    init(from primitive: Primitive) throws
    /// Returns the value as a CBOR primitive, ready to encode.
    /// - Returns: The CBOR item that represents this value.
    /// - Throws: `CardanoCoreError` when the value cannot be represented.
    func toPrimitive() throws -> Primitive
    /// Encodes the value as CBOR bytes.
    /// - Parameter deterministic: Requests deterministic encoding. The default
    ///   implementation ignores it and writes the value as ``toPrimitive()``
    ///   gives it, so map-key order is the order the value holds.
    /// - Returns: The CBOR bytes.
    func toCBORData(deterministic: Bool) throws -> Data
    /// Encodes the value as CBOR and returns the bytes as a hex string.
    /// - Parameter deterministic: Passed on to ``toCBORData(deterministic:)``.
    /// - Returns: The CBOR bytes as lowercase hex.
    func toCBORHex(deterministic: Bool) throws -> String
    /// Decodes a value from CBOR bytes.
    /// - Parameter data: The CBOR bytes.
    /// - Returns: The decoded value.
    /// - Throws: An error when the bytes are not valid CBOR or do not
    ///   describe this type.
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
    /// Defaults to `false`: the type reads the normalized primitive.
    public static var preservesEncoding: Bool { false }

    /// Decodes the value by reading a ``Primitive`` from the decoder and
    /// passing it to `init(from primitive:)`.
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: Decoder) throws {
        let primitive = try Primitive.decode(
            from: decoder, preservingEncoding: Self.preservesEncoding)
        try self.init(from: primitive)
    }
    
    /// Decodes a value from CBOR bytes.
    /// - Parameter cbor: The CBOR bytes.
    /// - Throws: An error when the bytes are not valid CBOR or do not
    ///   describe this type.
    public init(from cbor: Data) throws {
        self = try CBORDecoder.ledger().decode(Self.self, from: cbor)
    }
    
    /// Encodes the value as the primitive ``toPrimitive()`` returns.
    /// - Parameter encoder: The encoder to write to.
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toPrimitive())
    }
    
    /// Encodes the value as CBOR bytes.
    ///
    /// `deterministic` is currently ignored: indefinite-length items are kept
    /// so they round-trip, and map keys are written in the order the value
    /// holds them.
    /// - Parameter deterministic: Reserved for a Cardano-specific
    ///   deterministic mode. Defaults to `false`.
    /// - Returns: The CBOR bytes.
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
    
    /// Encodes the value as CBOR and returns the bytes as a hex string.
    /// - Parameter deterministic: Passed on to ``toCBORData(deterministic:)``.
    ///   Defaults to `false`.
    /// - Returns: The CBOR bytes as lowercase hex.
    public func toCBORHex(deterministic: Bool = false) throws -> String {
        return try toCBORData(deterministic: deterministic).toHex
    }
    
    /// Decodes a value from CBOR bytes with the ledger decoder.
    /// - Parameter data: The CBOR bytes.
    /// - Returns: The decoded value.
    public static func fromCBOR(data: Data) throws -> Self {
        return try CBORDecoder.ledger().decode(Self.self, from: data)
    }
    
    /// Decodes a value from a hex string of CBOR bytes.
    /// - Parameter hexString: The CBOR bytes as hex.
    /// - Returns: The decoded value.
    /// - Throws: `CardanoCoreError.invalidArgument` when the string is not
    ///   valid hex, or a decoding error from ``fromCBOR(data:)``.
    public static func fromCBORHex(_ hexString: String) throws -> Self {
        guard let data = Data(hexString: hexString) else {
            throw CardanoCoreError.invalidArgument("Invalid hex string: \(hexString)")
        }
        return try fromCBOR(data: data)
    }

}
