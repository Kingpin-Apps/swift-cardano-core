import Foundation
import CBORCodable
import SwiftNaCl

/// An Ed25519 stake signing key, which signs for a stake credential.
/// Its text-envelope type is `StakeSigningKeyShelley_ed25519`.
public struct StakeSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeSigningKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Stake Signing Key" }
    
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

/// An Ed25519 stake verification key, whose hash can be a stake credential.
/// Its text-envelope type is `StakeVerificationKeyShelley_ed25519`.
public struct StakeVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeVerificationKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Stake Verification Key" }
    
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
    
    /// The reward account of this key: the binary reward address whose stake
    /// credential is the 28-byte Blake2b-224 hash of this key.
    /// - Parameter network: The network the reward address is for.
    /// - Returns: The 29-byte reward account.
    public func rewardAccountHash(network: NetworkId) throws -> RewardAccountHash {
        let vKeyHash = VerificationKeyHash(
            payload: try SwiftNaCl.Hash().blake2b(
                data: payload,
                digestSize: VERIFICATION_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
        let address = try Address(stakingPart: .verificationKeyHash(vKeyHash), network: network)
        return RewardAccountHash(payload: address.toBytes())
    }
}

/// A BIP32-Ed25519 extended stake signing key, as derived from an HD wallet.
/// Its text-envelope type is `StakeExtendedSigningKeyShelley_ed25519_bip32`.
public struct StakeExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeExtendedSigningKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Stake Signing Key" }
    
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

/// A BIP32-Ed25519 extended stake verification key: the public key and chain code.
/// Its text-envelope type is `StakeExtendedVerificationKeyShelley_ed25519_bip32`.
public struct StakeExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeExtendedVerificationKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Stake Verification Key" }
    
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

/// A stake signing key together with its verification key.
public struct StakeKeyPair {
    /// The stake signing key.
    public let signingKey: StakeSigningKey
    /// The stake verification key.
    public let verificationKey: StakeVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: StakeSigningKey, verificationKey: StakeVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakeKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> StakeKeyPair {
        let signingKey = try StakeSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakeKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: StakeSigningKey) throws -> StakeKeyPair {
        let verificationKey: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(signingKey)
        return StakeKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakeKeyPair
extension StakeKeyPair: Equatable {
    public static func == (lhs: StakeKeyPair, rhs: StakeKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

