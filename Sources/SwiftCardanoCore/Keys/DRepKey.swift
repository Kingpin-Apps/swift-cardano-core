import Foundation
import CBORCodable

/// An Ed25519 signing key of a delegated representative (DRep).
/// Its text-envelope type is `DRepSigningKey_ed25519`.
public struct DRepSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "DRepSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Delegated Representative Signing Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// An Ed25519 verification key of a delegated representative (DRep).
/// Its text-envelope type is `DRepVerificationKey_ed25519`.
public struct DRepVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "DRepVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Delegated Representative Verification Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// A DRep signing key together with its verification key.
public struct DRepKeyPair {
    /// The DRep signing key.
    public let signingKey: DRepSigningKey
    /// The DRep verification key.
    public let verificationKey: DRepVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: DRepSigningKey, verificationKey: DRepVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new DRepKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> DRepKeyPair {
        let signingKey = try DRepSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a DRepKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: DRepSigningKey) throws -> DRepKeyPair {
        let verificationKey: DRepVerificationKey = try DRepVerificationKey.fromSigningKey(signingKey)
        return DRepKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension DRepKeyPair: Equatable {
    public static func == (lhs: DRepKeyPair, rhs: DRepKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
