import Foundation
import SwiftNcal
import PotentCBOR
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

public protocol VerificationKeyProtocol: PayloadCBORSerializable {}
public protocol ExtendedVerificationKeyProtocol: PayloadCBORSerializable {}

public extension VerificationKeyProtocol {
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
    
    static func fromSigningKey<T>(_ key: any SigningKeyProtocol) throws -> T where T: VerificationKeyProtocol {
        return try key.toVerificationKey()
    }
}

public extension ExtendedVerificationKeyProtocol {
    /// Compute a blake2b hash from the key, excluding chain code
    /// - Returns: VerificationKeyHash as the hash output in bytes
    func hash<T: VerificationKeyProtocol>() throws -> (VerificationKeyHash, T) {
        let nonExtendedKey: T = try self.toNonExtended()
        return (try nonExtendedKey.hash(), nonExtendedKey)
    }
    
    /// Generate ExtendedVerificationKey from an ExtendedSigningKey
    /// - Parameter key: ExtendedSigningKey instance
    /// - Returns: ExtendedVerificationKey
    static func fromSigningKey<T>(_ key: any ExtendedSigningKeyProtocol) throws -> T where T: ExtendedVerificationKeyProtocol {
        return try key.toVerificationKey()
    }
    
    /// Get the 32-byte verification key with chain code trimmed off
    /// - Returns: VerificationKey (non-extended)
    func toNonExtended<T>() throws -> T where T: VerificationKeyProtocol {
        return try T(payload: payload.prefix(32))
    }
}

/// Holds a cryptographic key and some metadata for a verification key.
public struct VerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


/// Holds a cryptographic key and some metadata for an extended verification key.
public struct ExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


public enum VerificationKeyType: CBORSerializable, Equatable, Hashable {

    case extendedVerificationKey(any ExtendedVerificationKeyProtocol)
    case verificationKey(any VerificationKeyProtocol)
    
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
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid VerificationKeyType primitive")
        }
        
        // Determine key type based on data length
        if data.count == 32 {
            // Regular verification key (32 bytes)
            self = .verificationKey(VerificationKey(payload: data, type: nil, description: nil))
        } else if data.count == 64 {
            // Extended verification key (64 bytes: 32 bytes key + 32 bytes chain code)
            self = .extendedVerificationKey(ExtendedVerificationKey(payload: data, type: nil, description: nil))
        } else {
            throw CardanoCoreError.deserializeError("Invalid verification key length: \(data.count) bytes. Expected 32 or 64 bytes.")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .extendedVerificationKey(let key):
            return .bytes(key.payload)
        case .verificationKey(let key):
            return .bytes(key.payload)
        }
    }
}
