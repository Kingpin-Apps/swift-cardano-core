import Foundation
import SwiftNaCl
import CBORCodable
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// A verification key with a text-envelope type and description.
/// The default ``hash()``, ``fromSigningKey(_:)`` and ``verify(signature:data:)``
/// treat the payload as an Ed25519 key; the VRF and KES key types replace them.
public protocol VerificationKeyProtocol: PayloadCBORSerializable {}
/// A BIP32-Ed25519 extended verification key: a 32-byte public key followed by a
/// 32-byte chain code.
public protocol ExtendedVerificationKeyProtocol: PayloadCBORSerializable {}

public extension VerificationKeyProtocol {
    /// The 28-byte Blake2b-224 hash of this key.
    /// - Returns: The verification key hash.
    func hash() throws -> VerificationKeyHash {
        return VerificationKeyHash(
            payload: try SwiftNaCl.Hash().blake2b(
                data: payload,
                digestSize: VERIFICATION_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    /// The verification key of a signing key.
    /// - Parameter key: The signing key.
    /// - Returns: Its verification key, of this type.
    static func fromSigningKey(_ key: any SigningKeyProtocol) throws -> Self {
        return try key.toVerificationKey()
    }

    /// Check an Ed25519 signature made by this key's signing key.
    /// - Parameters:
    ///   - signature: The 64-byte signature.
    ///   - data: The data that was signed.
    /// - Returns: Whether the signature is valid for `data`.
    /// - Throws: `CardanoCoreError.invalidKeyTypeError` when the key is not 32 bytes.
    func verify(signature: Data, data: Data) throws -> Bool {
        try ed25519Verify(publicKey: payload, signature: signature, data: data)
    }
}

/// Whether `signature` is a valid Ed25519 signature of `data` by `publicKey`.
func ed25519Verify(publicKey: Data, signature: Data, data: Data) throws -> Bool {
    guard publicKey.count == 32 else {
        throw CardanoCoreError.invalidKeyTypeError(
            "An Ed25519 verification key is 32 bytes, got \(publicKey.count)")
    }
    guard signature.count == 64 else { return false }
    let verifyKey = try SwiftNaCl.VerifyKey(key: publicKey)
    return (try? verifyKey.verify(smessage: data, signature: signature)) != nil
}

/// The fields of a key text-envelope file, with `cborHex` decoded to the key bytes.
struct KeyEnvelope {
    /// The envelope `type`.
    let type: String
    /// The envelope `description`.
    let description: String
    /// The key bytes that `cborHex` holds.
    let payload: Data

    /// Reads a key text-envelope file and checks that its `type` names the
    /// expected kind of key, so a signing key file is not read as a
    /// verification key or the other way round.
    /// - Parameters:
    ///   - path: The file path.
    ///   - kind: The kind the `type` must name, `"SigningKey"` or `"VerificationKey"`.
    ///   - otherKind: The kind the `type` must not name.
    /// - Throws: `CardanoCoreError.valueError` when the file is not a text envelope,
    ///   and `CardanoCoreError.invalidKeyTypeError` when its `type` is not of `kind`.
    init(path: String, kind: String, otherKind: String) throws {
        let jsonString = try readTextFile(path)
        guard let data = jsonString.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
        guard let type = dict["type"],
              let _ = dict["description"],
              let _ = dict["cborHex"] else {
            throw CardanoCoreError.valueError("Invalid Dictionary")
        }
        guard type.contains(kind), !type.contains(otherKind) else {
            throw CardanoCoreError.invalidKeyTypeError(
                "Expect a \(kind) envelope type, but got \(type)")
        }
        // VerificationKey has no envelope type or length of its own, so it
        // decodes any key's bytes, type and description unchanged.
        let raw = try VerificationKey.fromDict(dict, validateType: false)
        self.type = raw.type
        self.description = raw.description
        self.payload = raw.payload
    }
}

public extension ExtendedVerificationKeyProtocol {
    /// The 28-byte Blake2b-224 hash of the 32-byte public key, without the chain code.
    /// - Returns: The hash and the non-extended key it was computed from.
    func hash<T: VerificationKeyProtocol>() throws -> (VerificationKeyHash, T) {
        let nonExtendedKey: T = try self.toNonExtended()
        return (try nonExtendedKey.hash(), nonExtendedKey)
    }
    
    /// Generate ExtendedVerificationKey from an ExtendedSigningKey
    /// - Parameter key: ExtendedSigningKey instance
    /// - Returns: ExtendedVerificationKey
    static func fromSigningKey(_ key: any ExtendedSigningKeyProtocol) throws -> Self {
        return try key.toVerificationKey()
    }

    /// Check an Ed25519 signature made by this key's signing key. The chain
    /// code plays no part: the first 32 bytes are the public key.
    /// - Parameters:
    ///   - signature: The 64-byte signature.
    ///   - data: The data that was signed.
    /// - Returns: Whether the signature is valid for `data`.
    func verify(signature: Data, data: Data) throws -> Bool {
        try ed25519Verify(publicKey: payload.prefix(32), signature: signature, data: data)
    }
    
    /// Get the 32-byte verification key with chain code trimmed off
    /// - Returns: VerificationKey (non-extended)
    func toNonExtended<T>() throws -> T where T: VerificationKeyProtocol {
        return try T(payload: payload.prefix(32))
    }
}

/// The bytes, type and description of a verification key, for use with
/// ``VerificationKeyType`` and as a base for the role-specific key types.
public struct VerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Verification Key" }
    
    /// Creates a key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for the default.
    ///   - description: The text-envelope description, or `nil` for the default.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


/// The bytes, type and description of an extended verification key, for use with
/// ``VerificationKeyType`` and as a base for the role-specific key types.
public struct ExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Verification Key" }
    
    /// Creates a key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for the default.
    ///   - description: The text-envelope description, or `nil` for the default.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


/// A verification key that is either a plain or an extended verification key.
/// From a primitive, 32 bytes give a plain key and 64 bytes an extended key.
public enum VerificationKeyType: CBORSerializable, Sendable {

    /// An extended verification key: public key and chain code.
    case extendedVerificationKey(any ExtendedVerificationKeyProtocol)
    /// A plain 32-byte Ed25519 verification key.
    case verificationKey(any VerificationKeyProtocol)
    
    /// The raw bytes of the wrapped key.
    public var payload: Data {
        switch self {
            case .extendedVerificationKey(let key):
                return key.payload
            case .verificationKey(let key):
                return key.payload
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

    /// Check an Ed25519 signature made by this key's signing key.
    /// - Parameters:
    ///   - signature: The 64-byte signature.
    ///   - data: The data that was signed.
    /// - Returns: Whether the signature is valid for `data`.
    public func verify(signature: Data, data: Data) throws -> Bool {
        try ed25519Verify(publicKey: payload.prefix(32), signature: signature, data: data)
    }
    
    /// Load a verification key from a text-envelope file.
    ///
    /// The file's `type` must name a verification key, so a signing key file
    /// is never read as one. A 32-byte key gives a plain key and a 64-byte key
    /// an extended key; the file's type and description are kept.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    /// - Throws: `CardanoCoreError.invalidKeyTypeError` when the file holds another
    ///   kind of key, and `CardanoCoreError.deserializeError` when the key is not
    ///   32 or 64 bytes.
    public static func load(from path: String) throws -> Self {
        let envelope = try KeyEnvelope(path: path, kind: "VerificationKey", otherKind: "SigningKey")

        switch envelope.payload.count {
            case 32:
                return .verificationKey(VerificationKey(
                    payload: envelope.payload, type: envelope.type, description: envelope.description))
            case 64:
                return .extendedVerificationKey(ExtendedVerificationKey(
                    payload: envelope.payload, type: envelope.type, description: envelope.description))
            default:
                throw CardanoCoreError.deserializeError(
                    "Invalid verification key length: \(envelope.payload.count) bytes. Expected 32 or 64 bytes.")
        }
    }
    
    /// Save the JSON representation to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and overwrite is false.
    public func save(to path: String, overwrite: Bool = false) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        switch self {
            case .extendedVerificationKey(let key):
                try key.save(to: path, overwrite: overwrite)
            case .verificationKey(let key):
                try key.save(to: path, overwrite: overwrite)
        }
    }
    
}
