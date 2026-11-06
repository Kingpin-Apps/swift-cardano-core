import Foundation
import CBORCodable
import SwiftNaCl

/// An Ed25519 stake pool operator (cold) signing key.
/// Its text-envelope type is `StakePoolSigningKey_ed25519`.
public struct StakePoolSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakePoolSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Stake Pool Operator Signing Key" }
    
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

/// An Ed25519 stake pool operator (cold) verification key, whose hash is the pool ID.
/// Its text-envelope type is `StakePoolVerificationKey_ed25519`.
public struct StakePoolVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakePoolVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Stake Pool Operator Verification Key" }
    
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
    
    /// The pool ID: the 28-byte Blake2b-224 hash of this key.
    /// - Returns: The pool key hash.
    public func poolKeyHash() throws -> PoolKeyHash {
        return PoolKeyHash(
            payload: try SwiftNaCl.Hash().blake2b(
                data: payload,
                digestSize: POOL_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
}

/// A stake pool operator signing key together with its verification key.
public struct StakePoolKeyPair {
    /// The stake pool operator signing key.
    public let signingKey: StakePoolSigningKey
    /// The stake pool operator verification key.
    public let verificationKey: StakePoolVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: StakePoolSigningKey, verificationKey: StakePoolVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakePoolKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> StakePoolKeyPair {
        let signingKey = try StakePoolSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakePoolKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: StakePoolSigningKey) throws -> StakePoolKeyPair {
        let verificationKey: StakePoolVerificationKey = try StakePoolVerificationKey.fromSigningKey(signingKey)
        return StakePoolKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakePoolKeyPair
extension StakePoolKeyPair: Equatable {
    public static func == (lhs: StakePoolKeyPair, rhs: StakePoolKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
