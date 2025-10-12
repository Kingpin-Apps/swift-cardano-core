import Foundation
import SwiftNcal
import PotentCBOR
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

public protocol SigningKeyProtocol: PayloadCBORSerializable {}
public protocol ExtendedSigningKeyProtocol: PayloadCBORSerializable {}

public extension SigningKeyProtocol {
    func sign(data: Data) throws -> Data {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        let signedMessage = try signingKey.sign(message: data)
        return signedMessage.getSignature
    }
    
    
    func toVerificationKey<T>() throws -> T where T: VerificationKeyProtocol {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        var vkey =  try T(
            payload: signingKey.verifyKey.bytes,
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
        vkey._payload = signingKey.verifyKey.bytes
        return vkey        
    }

    
    static func generate() throws -> Self {
        let signingKey = try SwiftNcal.SigningKey.generate()
        var sKey = try Self(payload: signingKey.bytes)
        sKey._payload = signingKey.bytes
        return sKey
    }
}

public extension ExtendedSigningKeyProtocol {
    
    func sign(data: Data) throws -> Data {        
        let privateKey = try BIP32ED25519PrivateKey(
            privateKey: payload.prefix(64),  // First 64 bytes
            chainCode: payload.suffix(from: 96)  // From byte 96 onwards
        )
        
        let signedMessage = try privateKey.sign(message: data)
        return signedMessage
    }

    func toVerificationKey<T>() throws -> T where T: ExtendedVerificationKeyProtocol {
        return try T(
            payload: payload.suffix(from: 64),
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
    }

    static func fromHDWallet(_ hdwallet: HDWallet) throws -> any ExtendedSigningKeyProtocol {
        let payload = hdwallet.xPrivateKey + hdwallet.publicKey + hdwallet.chainCode
        
        return try Self(
            payload: payload,
            type: "PaymentExtendedSigningKeyShelley_ed25519_bip32",
            description: "Payment Signing Key"
        )
    }
}

/// Holds a cryptographic key and some metadata for a signing key.
public struct SigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// Holds a cryptographic key and some metadata for an extended signing key.
public struct ExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public enum SigningKeyType: Codable, Equatable, Hashable {

    case extendedSigningKey(any ExtendedSigningKeyProtocol)
    case signingKey(any SigningKeyProtocol)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        if data.count == 64 {
            self = .signingKey(try SigningKey(payload: data))
        } else {
            self = .extendedSigningKey(try ExtendedSigningKey(payload: data))
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .extendedSigningKey(let key):
                try container.encode(key)
            case .signingKey(let key):
                try container.encode(key)
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
    
    public func toVerificationKeyType() throws -> VerificationKeyType {
        switch self {
            case .extendedSigningKey(let key):
                if let skey = key as? PaymentExtendedSigningKey {
                    let evkey: PaymentExtendedVerificationKey = try skey.toVerificationKey()
                    return .extendedVerificationKey(evkey)
                } else if let skey = key as? StakeExtendedSigningKey {
                    let evkey: StakeExtendedVerificationKey = try skey.toVerificationKey()
                    return .extendedVerificationKey(evkey)
                } else if let skey = key as? ExtendedSigningKey {
                    let evkey: ExtendedVerificationKey = try skey.toVerificationKey()
                    return .extendedVerificationKey(evkey)
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
}
