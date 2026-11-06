import Foundation
import CBORCodable

/// A value made of raw bytes plus the `type` and `description` fields of a
/// cardano-cli text envelope.
public protocol Payloadable {
    /// The raw bytes the value holds.
    var _payload: Data { get set }
    /// The text envelope's `type` field, for example `PaymentSigningKeyShelley_ed25519`.
    var _type: String { get set }
    /// The text envelope's `description` field.
    var _description: String { get set }
}

public extension Payloadable {
    /// The raw bytes the value holds.
    var payload: Data { get { return _payload } }
    /// The text envelope's `type` field.
    var type: String { get { return _type } }
    /// The text envelope's `description` field.
    var description: String { get { return _description } }
}

/// A ``Payloadable`` value that is also CBOR serializable, with a default
/// envelope `type` and `description` for its kind.
///
/// Equality compares the payload, type and description; hashing uses the
/// payload only.
public protocol PayloadSerializable: Payloadable, CBORSerializable, Sendable {
    /// The default text envelope `type` for this kind of value. Empty when
    /// the kind has no envelope type of its own.
    static var TYPE: String { get }
    /// The default text envelope `description` for this kind of value.
    static var DESCRIPTION: String { get }
    
    /// Creates a value from raw bytes and envelope fields.
    /// - Parameters:
    ///   - payload: The raw bytes.
    ///   - type: The text envelope `type`, or `nil` for the type's default.
    ///   - description: The text envelope `description`, or `nil` for the
    ///     type's default.
    /// - Throws: `CardanoCoreError` when the bytes are not valid for this type.
    init(payload: Data, type: String?, description: String?) throws
}

public extension PayloadSerializable {
    /// Creates a value from raw bytes with the type's default ``TYPE`` and
    /// ``DESCRIPTION``.
    /// - Parameter payload: The raw bytes.
    /// - Throws: `CardanoCoreError` when the bytes are not valid for this type.
    init(payload: Data) throws {
        try self.init(payload: payload, type: Self.TYPE, description: Self.DESCRIPTION)
    }
    
    /// Convert to raw bytes
    /// - Returns: The raw bytes
    func toBytes() -> Data {
        return payload
    }
    
    // Equality check
    /// Returns whether two values have the same payload, type and description.
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload &&
               lhs.description == rhs.description && lhs.type == rhs.type
    }
    
    /// Hashes the payload. Type and description are left out.
    /// - Parameter hasher: The hasher.
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}
