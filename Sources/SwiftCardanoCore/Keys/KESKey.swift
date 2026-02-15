import Foundation
import SwiftNcal
import SwiftKES
import PotentCBOR

/// A KES (Key Evolving Signature) signing key.
///
/// KES keys are forward-secure: after evolving to a new period, old key material
/// is securely zeroed, making it impossible to forge signatures for past periods.
///
/// Cardano uses Sum6KES with depth 6, providing 64 signing periods.
public struct KESSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "KesSigningKey_ed25519_kes_2^6" }
    public static var DESCRIPTION: String { "KES Signing Key" }

    /// The current signing period (0-based, max 63 for Sum6KES)
    public private(set) var currentPeriod: UInt

    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        self.currentPeriod = 0
    }

    /// Initialize a KES signing key with a specific period.
    ///
    /// - Parameters:
    ///   - payload: The raw 608-byte secret key data
    ///   - period: The current period for this key
    ///   - type: Optional type string
    ///   - description: Optional description string
    public init(payload: Data, period: UInt, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        self.currentPeriod = period
    }

    public func sign(data: Data) throws -> Data {
        let kes = try Sum6KES(secretKeyBytes: payload, period: currentPeriod)
        let signature = try kes.sign(message: data)
        return signature.bytes
    }

    /// Sign data and return the signature along with the period used.
    ///
    /// - Parameter data: The data to sign
    /// - Returns: A tuple containing the signature bytes and the period used
    public func signWithPeriod(data: Data) throws -> (signature: Data, period: UInt) {
        let kes = try Sum6KES(secretKeyBytes: payload, period: currentPeriod)
        let signature = try kes.sign(message: data)
        return (signature.bytes, currentPeriod)
    }

    /// Evolve the key to the next period.
    ///
    /// This mutates the key in place, securely zeroing old key material.
    /// After calling this method, the key can sign for the next period.
    ///
    /// - Throws: `KESError.keyExhausted` if the key has reached its final period (63)
    public mutating func evolve() throws {
        var kes = try Sum6KES(secretKeyBytes: payload, period: currentPeriod)
        try kes.evolve()
        self._payload = kes.secretKeyBytes
        self.currentPeriod = kes.currentPeriod
    }

    /// Check if the key can still evolve to another period.
    public var canEvolve: Bool {
        return currentPeriod < Sum6KES.totalPeriods - 1
    }

    /// The maximum number of periods this key supports.
    public static var totalPeriods: UInt {
        return Sum6KES.totalPeriods
    }

    public func toVerificationKey() throws -> KESVerificationKey {
        return try KESVerificationKey.fromSigningKey(self)
    }

    public static func generate() throws -> Self {
        let keyPair = try KESKeyPair.generate()
        return keyPair.signingKey
    }

    /// Generate a new KES signing key from a 32-byte seed.
    ///
    /// - Parameter seed: Exactly 32 bytes of entropy
    /// - Returns: A new KES signing key at period 0
    public static func fromSeed(_ seed: Data) throws -> Self {
        let kes = try Sum6KES(seed: seed)
        return KESSigningKey(
            payload: kes.secretKeyBytes,
            period: 0,
            type: nil,
            description: nil
        )
    }
}

/// A KES (Key Evolving Signature) verification key.
///
/// The verification key remains constant across all signing periods.
/// It is a 32-byte Blake2b-256 hash of the root public key.
public struct KESVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "KesVerificationKey_ed25519_kes_2^6" }
    public static var DESCRIPTION: String { "KES Verification Key" }

    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    /// Compute a blake2b hash from the key.
    ///
    /// - Returns: Hash output as a `KesKeyHash`
    public func hash() throws -> KesKeyHash {
        return KesKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: KES_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }

    /// Verify a KES signature.
    ///
    /// - Parameters:
    ///   - signature: The signature bytes (448 bytes for Sum6KES)
    ///   - message: The original message that was signed
    ///   - period: The period at which the signature was produced
    /// - Returns: `true` if the signature is valid
    public func verify(signature: Data, message: Data, period: UInt) throws -> Bool {
        let kesPK = try SwiftKES.KESPublicKey(bytes: payload)
        let kesSig = try SwiftKES.KESSignature(depth: Sum6KES.depth, bytes: signature)
        return try Sum6KES.verify(
            publicKey: kesPK,
            period: period,
            signature: kesSig,
            message: message
        )
    }

    public static func fromSigningKey(_ key: KESSigningKey) throws -> KESVerificationKey {
        let kes = try Sum6KES(secretKeyBytes: key.payload, period: key.currentPeriod)
        return try KESVerificationKey(payload: kes.publicKey.bytes)
    }
}

/// A KES key pair containing both signing and verification keys.
public struct KESKeyPair {
    public let signingKey: KESSigningKey
    public let verificationKey: KESVerificationKey

    public init(signingKey: KESSigningKey, verificationKey: KESVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }

    /// Generate a new KES key pair from random entropy.
    public static func generate() throws -> KESKeyPair {
        // Generate 32 bytes of random entropy for the seed
        var seed = Data(count: 32)
        let result = seed.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw CardanoCoreError.valueError("Failed to generate random seed")
        }

        return try fromSeed(seed)
    }

    /// Generate a KES key pair from a 32-byte seed.
    ///
    /// - Parameter seed: Exactly 32 bytes of entropy
    /// - Returns: A new KES key pair
    public static func fromSeed(_ seed: Data) throws -> KESKeyPair {
        let kes = try Sum6KES(seed: seed)
        let signingKey = KESSigningKey(
            payload: kes.secretKeyBytes,
            period: 0,
            type: nil,
            description: nil
        )
        let verificationKey = try KESVerificationKey(payload: kes.publicKey.bytes)
        return KESKeyPair(signingKey: signingKey, verificationKey: verificationKey)
    }

    /// Restore a KES key pair from an existing signing key.
    public static func fromSigningKey(_ signingKey: KESSigningKey) throws -> KESKeyPair {
        let verificationKey = try KESVerificationKey.fromSigningKey(signingKey)
        return KESKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// MARK: - Equatable Protocol for KESKeyPair

extension KESKeyPair: Equatable {
    public static func == (lhs: KESKeyPair, rhs: KESKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

// MARK: - KesKeyHash

/// Hash of a Cardano KES verification key.
public struct KesKeyHash: ConstrainedBytes, Hashable, Equatable {
    public var payload: Data
    public static var maxSize: Int { KES_KEY_HASH_SIZE }
    public static var minSize: Int { KES_KEY_HASH_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}
