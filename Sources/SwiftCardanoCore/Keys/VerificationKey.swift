import Foundation
import CryptoKit
import SwiftNcal

protocol VerificationKey: PayloadCBORSerializable {}
protocol ExtendedVerificationKey: PayloadCBORSerializable {}

extension VerificationKey {
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
    
    static func fromSigningKey<T>(_ key: any SigningKey) throws -> T where T: VerificationKey {
        return try key.toVerificationKey()
    }
}

extension ExtendedVerificationKey {
    /// Compute a blake2b hash from the key, excluding chain code
    /// - Returns: VerificationKeyHash as the hash output in bytes
    func hash<T: VerificationKey>() throws -> (VerificationKeyHash, T) {
        let nonExtendedKey: T = self.toNonExtended()
        return (try nonExtendedKey.hash(), nonExtendedKey)
    }
    
    /// Generate ExtendedVerificationKey from an ExtendedSigningKey
    /// - Parameter key: ExtendedSigningKey instance
    /// - Returns: ExtendedVerificationKey
    static func fromSigningKey<T>(_ key: any ExtendedSigningKey) -> T where T: ExtendedVerificationKey {
        return key.toVerificationKey()
    }
    
    /// Get the 32-byte verification key with chain code trimmed off
    /// - Returns: VerificationKey (non-extended)
    func toNonExtended<T>() -> T where T: VerificationKey {
        return T(payload: payload.prefix(32))
    }
}
