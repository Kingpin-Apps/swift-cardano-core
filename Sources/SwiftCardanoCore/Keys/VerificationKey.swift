import Foundation
import CryptoKit
import SwiftNcal

public protocol VerificationKey: PayloadCBORSerializable {}
public protocol ExtendedVerificationKey: PayloadCBORSerializable {}

public extension VerificationKey {
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

public extension ExtendedVerificationKey {
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

public enum VerificationKeyType: Codable, Equatable, Hashable {

    case extendedVerificationKey(any ExtendedVerificationKey)
    case verificationKey(any VerificationKey)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        if data.count == 64 {
            self = .verificationKey(VKey(payload: data))
        } else {
            self = .extendedVerificationKey(ExtendedVKey(payload: data))
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .extendedVerificationKey(let key):
                try container.encode(key)
            case .verificationKey(let key):
                try container.encode(key)
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
            case .extendedVerificationKey(let key):
                hasher.combine(key)
            case .verificationKey(let key):
                hasher.combine(key)
        }
    }
    
    public static func == (lhs: VerificationKeyType, rhs: VerificationKeyType) -> Bool {
        let lhsData: Data
        let rhsData: Data
        
        switch lhs {
            case .extendedVerificationKey(let key):
                lhsData = key.payload
            case .verificationKey(let key):
                lhsData = key.payload
        }
        
        switch rhs {
            case .extendedVerificationKey(let key):
                rhsData = key.payload
            case .verificationKey(let key):
                rhsData = key.payload
        }
        
        return lhsData == rhsData
    }
}
