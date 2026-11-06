import Foundation
import SwiftNaCl
import CBORCodable

/// A stake pool's VRF signing key, which makes VRF proofs rather than signatures.
/// Its text-envelope type is `VrfSigningKey_PraosVRF`.
public struct VRFSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfSigningKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Signing Key" }
    
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
    
    /// Not supported: VRF keys make proofs, not signatures.
    /// - Throws: `CardanoCoreError.invalidOperation`, always. Use ``prove(message:)`` instead.
    public func sign(data: Data) throws -> Data {
        throw CardanoCoreError.invalidOperation(
            "VRF keys do not support signing. Use prove(message:) to generate a VRF proof."
        )
    }

    /// Create a VRF proof for a given message
    ///
    /// - Parameter message: The message to create a proof for
    /// - Returns: The VRF proof bytes (80 bytes)
    public func prove(message: Data) throws -> Data {
        let signingKey = try SwiftNaCl.VRFSigningKey(bytes: payload)
        let proof = try signingKey.prove(message: message)
        return proof.bytes
    }

    /// Create a VRF certificate (proof + output) for a given message
    ///
    /// This produces a complete ``VRFCert`` containing both the VRF output
    /// and the VRF proof, suitable for use in block headers.
    ///
    /// - Parameter message: The message to create a VRF certificate for
    /// - Returns: A ``VRFCert`` containing the VRF output and proof
    public func certify(message: Data) throws -> VRFCert {
        let signingKey = try SwiftNaCl.VRFSigningKey(bytes: payload)
        let proof = try signingKey.prove(message: message)
        let output = try proof.hash()
        return try VRFCert(output: output.bytes, proof: proof.bytes)
    }
    
    /// The VRF verification key of this signing key.
    public func toVerificationKey() throws -> VRFVerificationKey {
        return try VRFVerificationKey.fromSigningKey(self)
    }
    
    /// A new, randomly generated VRF signing key.
    public  static func generate() throws -> Self {
        let vrfKeyPair = try VRFKeyPair.generate()
        return vrfKeyPair.signingKey
    }
}

/// A stake pool's VRF verification key.
/// Its text-envelope type is `VrfVerificationKey_PraosVRF`.
public struct VRFVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfVerificationKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Verification Key" }
    
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
    
    /// The 32-byte Blake2b-256 hash of this key.
    /// - Returns: The VRF key hash.
    public func hash() throws -> VrfKeyHash {
        return VrfKeyHash(
            payload: try SwiftNaCl.Hash().blake2b(
                data: payload,
                digestSize: VRF_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    /// VRF keys make proofs, not signatures, so there is nothing to verify.
    public func verify(signature: Data, data: Data) throws -> Bool {
        throw CardanoCoreError.invalidOperation(
            "VRF keys do not support signing, so there is no signature to verify."
        )
    }

    /// The VRF verification key of a VRF signing key.
    /// - Parameter key: The VRF signing key.
    /// - Returns: Its verification key.
    public static func fromSigningKey(_ key: VRFSigningKey) throws -> VRFVerificationKey {
        let vrfSKey = try SwiftNaCl.VRFSigningKey(bytes: key.payload)
        return try VRFVerificationKey(payload: vrfSKey.verifyingKey.bytes)
    }
}

/// A VRF signing key together with its verification key.
public struct VRFKeyPair {
    /// The VRF signing key.
    public let signingKey: VRFSigningKey
    /// The VRF verification key.
    public let verificationKey: VRFVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: VRFSigningKey, verificationKey: VRFVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new VRFKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> VRFKeyPair {
        let vrfKeyPair = SwiftNaCl.VRFKeyPair.generate()
        return VRFKeyPair(
            signingKey: try VRFSigningKey(
                payload: vrfKeyPair.signingKey.bytes
            ),
            verificationKey: try VRFVerificationKey(
                payload: vrfKeyPair.verifyingKey.bytes
            )
        )
    }
    
    // static a VRFKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: VRFSigningKey) throws -> VRFKeyPair {
        let verificationKey: VRFVerificationKey = try VRFVerificationKey.fromSigningKey(signingKey)
        return VRFKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for VRFKeyPair
extension VRFKeyPair: Equatable {
    public static func == (lhs: VRFKeyPair, rhs: VRFKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
        lhs.verificationKey == rhs.verificationKey
    }
}
