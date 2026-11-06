import Foundation
import SwiftNaCl
import CBORCodable
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// A signing key with a text-envelope type and description.
/// The default ``sign(data:)``, ``toVerificationKey()`` and ``generate()`` use
/// Ed25519 with the payload as the seed; the VRF and KES key types replace them.
public protocol SigningKeyProtocol: PayloadCBORSerializable {}
/// A BIP32-Ed25519 extended signing key, as derived from an HD wallet.
/// Its payload is the 64-byte extended private key, the 32-byte public key
/// and the 32-byte chain code, in that order.
public protocol ExtendedSigningKeyProtocol: PayloadCBORSerializable {}

public extension SigningKeyProtocol {
    /// Signs data with Ed25519, using the payload as the key seed.
    /// - Parameter data: The data to sign.
    /// - Returns: The signature.
    func sign(data: Data) throws -> Data {
        let signingKey = try SwiftNaCl.SigningKey(seed: payload)
        let signedMessage = try signingKey.sign(message: data)
        return signedMessage.getSignature
    }
    
    /// The verification key of this signing key.
    /// The type and description are this key's, with "Signing" replaced by "Verification".
    /// - Returns: The verification key, of the type the caller asks for.
    func toVerificationKey<T>() throws -> T where T: VerificationKeyProtocol {
        let signingKey = try SwiftNaCl.SigningKey(seed: payload)
        var vkey =  try T(
            payload: signingKey.verifyKey.bytes,
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
        vkey._payload = signingKey.verifyKey.bytes
        return vkey        
    }
    
    /// A new signing key from fresh random bytes.
    static func generate() throws -> Self {
        let signingKey = try SwiftNaCl.SigningKey.generate()
        var sKey = try Self(payload: signingKey.bytes)
        sKey._payload = signingKey.bytes
        return sKey
    }
}

public extension ExtendedSigningKeyProtocol {
    
    /// Signs data with the BIP32-Ed25519 extended private key in the first 64 bytes of the payload.
    /// - Parameter data: The data to sign.
    /// - Returns: The signature.
    func sign(data: Data) throws -> Data {        
        let privateKey = try BIP32ED25519PrivateKey(
            privateKey: payload.prefix(64),  // First 64 bytes
            chainCode: payload.suffix(from: 96)  // From byte 96 onwards
        )
        
        let signedMessage = try privateKey.sign(message: data)
        return signedMessage
    }

    /// The extended verification key of this signing key: the payload from byte 64 on,
    /// which is the public key followed by the chain code.
    /// - Returns: The extended verification key, of the type the caller asks for.
    func toVerificationKey<T>() throws -> T where T: ExtendedVerificationKeyProtocol {
        return try T(
            payload: payload.suffix(from: 64),
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
    }

    /// The extended signing key of an HD wallet node: its extended private
    /// key, public key and chain code, as cardano-cli writes them.
    /// - Parameter hdwallet: The wallet node, usually derived to a key's path.
    /// - Returns: The key, of this type.
    static func fromHDWallet(_ hdwallet: HDWallet) throws -> Self {
        let payload = hdwallet.xPrivateKey + hdwallet.publicKey + hdwallet.chainCode
        return try Self(payload: payload, type: nil, description: nil)
    }

    /// A new extended signing key: the root key of a wallet made from fresh
    /// 256-bit entropy.
    static func generate() throws -> Self {
        let mnemonic = try HDWallet.generateMnemonic(wordCount: .twentyFour)
        return try fromHDWallet(HDWallet.fromMnemonic(mnemonic: mnemonic.joined(separator: " ")))
    }
}

/// The bytes, type and description of a key, for use with
/// ``SigningKeyType`` and as a base for the role-specific key types.
public struct SigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Signing Key" }
    
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

/// The bytes, type and description of an extended key, for use with
/// ``SigningKeyType`` and as a base for the role-specific key types.
public struct ExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Signing Key" }
    
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

/// A signing key that is either a plain or an extended signing key.
public enum SigningKeyType: CBORSerializable, Sendable {

    /// An extended (BIP32-Ed25519) signing key.
    case extendedSigningKey(any ExtendedSigningKeyProtocol)
    /// A plain Ed25519 signing key.
    case signingKey(any SigningKeyProtocol)

    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid SigningKeyType primitive")
        }

        if data.count == 64 {
            self = .signingKey(try SigningKey(payload: data))
        } else {
            self = .extendedSigningKey(try ExtendedSigningKey(payload: data))
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .extendedSigningKey(let key):
                return .bytes(key.payload)
            case .signingKey(let key):
                return .bytes(key.payload)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
            case .extendedSigningKey(let key):
                hasher.combine(key)
            case .signingKey(let key):
                hasher.combine(key)
        }
    }
    
    public static func == (lhs: SigningKeyType, rhs: SigningKeyType) -> Bool {
        let lhsData: Data
        let rhsData: Data
        
        switch lhs {
            case .extendedSigningKey(let key):
                lhsData = key.payload
            case .signingKey(let key):
                lhsData = key.payload
        }
        
        switch rhs {
            case .extendedSigningKey(let key):
                rhsData = key.payload
            case .signingKey(let key):
                rhsData = key.payload
        }
        
        return lhsData == rhsData
    }
    
    /// Signs data with the wrapped key.
    /// - Parameter data: The data to sign.
    /// - Returns: The signature.
    /// - Throws: `CardanoCoreError.invalidKeyTypeError` when the wrapped key is not one of
    ///   the key types this module knows.
    public func sign(data: Data) throws -> Data {
        switch self {
            case .extendedSigningKey(let key):
                if let skey = key as? PaymentExtendedSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? StakeExtendedSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? ExtendedSigningKey {
                    return try skey.sign(data: data)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
            case .signingKey(let key):
                if let skey = key as? PaymentSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? StakeSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? CommitteeColdSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? DRepSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? StakePoolSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? VRFSigningKey {
                    return try skey.sign(data: data)
                } else if let skey = key as? SigningKey {
                    return try skey.sign(data: data)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
        }
    }
    
    /// The 32-byte verification key of the wrapped key.
    /// An extended key gives its non-extended verification key, without the chain code.
    /// - Returns: The verification key.
    /// - Throws: `CardanoCoreError.invalidKeyTypeError` when the wrapped key is not one of
    ///   the key types this module knows.
    public func toVerificationKey() throws -> any VerificationKeyProtocol {
        switch self {
            case .extendedSigningKey(let key):
                if let skey = key as? PaymentExtendedSigningKey {
                    let evkey: PaymentExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: PaymentVerificationKey = try evkey.toNonExtended()
                    return vkey
                } else if let skey = key as? StakeExtendedSigningKey {
                    let evkey: StakeExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: StakeVerificationKey = try evkey.toNonExtended()
                    return vkey
                } else if let skey = key as? ExtendedSigningKey {
                    let evkey: ExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: VerificationKey = try evkey.toNonExtended()
                    return vkey
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
            case .signingKey(let key):
                if let skey = key as? PaymentSigningKey {
                    let vkey: PaymentVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? StakeSigningKey {
                    let vkey: StakeVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? CommitteeColdSigningKey {
                    let vkey: CommitteeColdVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? DRepSigningKey {
                    let vkey: DRepVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? StakePoolSigningKey {
                    let vkey: StakePoolVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? VRFSigningKey {
                    let vkey: VRFVerificationKey = try skey.toVerificationKey()
                    return vkey
                } else if let skey = key as? SigningKey {
                    let vkey: VerificationKey = try skey.toVerificationKey()
                    return vkey
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
        }
    }
    
    /// The 32-byte verification key of the wrapped key, as a ``VerificationKeyType``.
    /// An extended key gives its non-extended verification key, without the chain code,
    /// since a transaction witness must carry the 32-byte key.
    /// - Returns: The verification key.
    /// - Throws: `CardanoCoreError.invalidKeyTypeError` when the wrapped key is not one of
    ///   the key types this module knows.
    public func toVerificationKeyType() throws -> VerificationKeyType {
        switch self {
            case .extendedSigningKey(let key):
                // A transaction vkey witness (and any address-deriving use) must
                // carry the non-extended 32-byte Ed25519 verification key. The
                // extended (64-byte) key embeds the BIP32 chain code, which the
                // ledger rejects with "decodeVerKeyDSIGN: wrong length, expected
                // 32 bytes but got 64". Collapse to the non-extended form here,
                // matching `toVerificationKey()`.
                if let skey = key as? PaymentExtendedSigningKey {
                    let evkey: PaymentExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: PaymentVerificationKey = try evkey.toNonExtended()
                    return .verificationKey(vkey)
                } else if let skey = key as? StakeExtendedSigningKey {
                    let evkey: StakeExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: StakeVerificationKey = try evkey.toNonExtended()
                    return .verificationKey(vkey)
                } else if let skey = key as? ExtendedSigningKey {
                    let evkey: ExtendedVerificationKey = try skey.toVerificationKey()
                    let vkey: VerificationKey = try evkey.toNonExtended()
                    return .verificationKey(vkey)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
            case .signingKey(let key):
                if let skey = key as? PaymentSigningKey {
                    let vkey: PaymentVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? StakeSigningKey {
                    let vkey: StakeVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? CommitteeColdSigningKey {
                    let vkey: CommitteeColdVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? DRepSigningKey {
                    let vkey: DRepVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? StakePoolSigningKey {
                    let vkey: StakePoolVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? VRFSigningKey {
                    let vkey: VRFVerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else if let skey = key as? SigningKey {
                    let vkey: VerificationKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
        }
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    public static func load(from path: String) throws -> Self {
        let jsonString = try readTextFile(path)
        
        guard let data = jsonString.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
        
        guard let _ = dict["type"],
              let _ = dict["description"],
              let cborHex = dict["cborHex"] else {
            throw CardanoCoreError.valueError("Invalid Dictionary")
        }
        
        if cborHex.count == 68 {
            return .signingKey(
                try SigningKey.load(from: path)
            )
        } else {
            return.extendedSigningKey(
                try ExtendedSigningKey.load(from: path)
            )
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
            case .extendedSigningKey(let key):
                try key.save(to: path, overwrite: overwrite)
            case .signingKey(let key):
                try key.save(to: path, overwrite: overwrite)
        }
    }
}
