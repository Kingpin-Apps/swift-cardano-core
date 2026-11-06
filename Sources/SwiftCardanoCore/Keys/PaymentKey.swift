import Foundation
import CBORCodable


/// An Ed25519 payment signing key, which signs for spending from a payment address.
/// Its text-envelope type is `PaymentSigningKeyShelley_ed25519`.
public struct PaymentSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentSigningKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Payment Signing Key" }
    
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

/// An Ed25519 payment verification key, whose hash can be the payment part of an address.
/// Its text-envelope type is `PaymentVerificationKeyShelley_ed25519`.
public struct PaymentVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentVerificationKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Payment Verification Key" }
    
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

/// A BIP32-Ed25519 extended payment signing key, as derived from an HD wallet.
/// Its text-envelope type is `PaymentExtendedSigningKeyShelley_ed25519_bip32`.
public struct PaymentExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentExtendedSigningKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Payment Signing Key" }
    
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

/// A BIP32-Ed25519 extended payment verification key: the public key and chain code.
/// Its text-envelope type is `PaymentExtendedVerificationKeyShelley_ed25519_bip32`.
public struct PaymentExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentExtendedVerificationKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Payment Verification Key" }
    
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

/// A payment signing key together with its verification key.
public struct PaymentKeyPair {
    /// The payment signing key.
    public let signingKey: PaymentSigningKey
    /// The payment verification key.
    public let verificationKey: PaymentVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: PaymentSigningKey, verificationKey: PaymentVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new PaymentKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> PaymentKeyPair {
        let signingKey = try PaymentSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: PaymentSigningKey) throws -> PaymentKeyPair {
        let verificationKey: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(signingKey)
        return PaymentKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension PaymentKeyPair: Equatable {
    public static func == (lhs: PaymentKeyPair, rhs: PaymentKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
