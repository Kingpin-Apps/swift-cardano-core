import Foundation
import CryptoKit
import SwiftNcal

class VerificationKey: Key {
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    func hash() throws -> VerificationKeyHash {
        return VerificationKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: VERIFICATION_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    static func fromSigningKey<T>(_ key: SigningKey) throws -> T where T: VerificationKey {
        return try key.toVerificationKey()
    }
}

class ExtendedVerificationKey: Key {
    /// Compute a blake2b hash from the key, excluding chain code
    /// - Returns: VerificationKeyHash as the hash output in bytes
    func hash() throws -> VerificationKeyHash {
        return try toNonExtended().hash()
    }
    
    /// Generate ExtendedVerificationKey from an ExtendedSigningKey
    /// - Parameter key: ExtendedSigningKey instance
    /// - Returns: ExtendedVerificationKey
    static func fromSigningKey(_ key: ExtendedSigningKey) -> ExtendedVerificationKey {
        return key.toVerificationKey() 
    }
    
    /// Get the 32-byte verification key with chain code trimmed off
    /// - Returns: VerificationKey (non-extended)
    func toNonExtended() -> VerificationKey {
        return VerificationKey(payload: payload.prefix(32))
    }
}
