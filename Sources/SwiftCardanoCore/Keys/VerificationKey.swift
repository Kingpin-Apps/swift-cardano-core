import Foundation
import CryptoKit
import SwiftNcal
import PotentCBOR

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
        let nonExtendedKey: T = self.toNonExtended()
        return (try nonExtendedKey.hash(), nonExtendedKey)
    }
    
    /// Generate ExtendedVerificationKey from an ExtendedSigningKey
    /// - Parameter key: ExtendedSigningKey instance
    /// - Returns: ExtendedVerificationKey
    static func fromSigningKey<T>(_ key: any ExtendedSigningKeyProtocol) -> T where T: ExtendedVerificationKeyProtocol {
        return key.toVerificationKey()
    }
    
    /// Get the 32-byte verification key with chain code trimmed off
    /// - Returns: VerificationKey (non-extended)
    func toNonExtended<T>() -> T where T: VerificationKeyProtocol {
        return T(payload: payload.prefix(32))
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
        // For verification keys, we should almost always use raw bytes
        // Only try CBOR decoding if the payload looks like it might be CBOR-encoded
        // and is significantly larger than expected key sizes (32 or 64 bytes)
        let actualPayload: Data
        
        if payload.count > 70 && payload.count > 32 && payload.count > 64 {
            // Only try CBOR decoding for significantly larger payloads that might be wrapped
            if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
                actualPayload = payloadData
            } else {
                actualPayload = payload
            }
        } else {
            // For payloads that are around the expected key size, use them directly
            actualPayload = payload
        }
        
        self._payload = actualPayload
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
        let actualPayload: Data
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            actualPayload = payloadData
        } else {
            actualPayload = payload
        }
        
        self._payload = actualPayload
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
