import Foundation
import SwiftNcal
import PotentCBOR

public struct VRFSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfSigningKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
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
        let signingKey = try SwiftNcal.VRFSigningKey(bytes: payload)
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
        let signingKey = try SwiftNcal.VRFSigningKey(bytes: payload)
        let proof = try signingKey.prove(message: message)
        let output = try proof.hash()
        return try VRFCert(output: output.bytes, proof: proof.bytes)
    }
    
    public func toVerificationKey() throws -> VRFVerificationKey {
        return try VRFVerificationKey.fromSigningKey(self)
    }
    
    public  static func generate() throws -> Self {
        let vrfKeyPair = try VRFKeyPair.generate()
        return vrfKeyPair.signingKey
    }
}

public struct VRFVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfVerificationKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    public func hash() throws -> VrfKeyHash {
        return VrfKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: VRF_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    public static func fromSigningKey(_ key: VRFSigningKey) throws -> VRFVerificationKey {
        let vrfSKey = try SwiftNcal.VRFSigningKey(bytes: key.payload)
        return try VRFVerificationKey(payload: vrfSKey.verifyingKey.bytes)
    }
}

public struct VRFKeyPair {
    public let signingKey: VRFSigningKey
    public let verificationKey: VRFVerificationKey
    
    public init(signingKey: VRFSigningKey, verificationKey: VRFVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new VRFKeyPair
    public static func generate() throws -> VRFKeyPair {
        let vrfKeyPair = SwiftNcal.VRFKeyPair.generate()
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
