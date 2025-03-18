import Foundation
import CryptoKit
import SwiftNcal

public protocol SigningKey: PayloadCBORSerializable {}
public protocol ExtendedSigningKey: PayloadCBORSerializable {}

public extension SigningKey {
    func sign(data: Data) throws -> Data {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        let signedMessage = try signingKey.sign(message: data)
        return signedMessage.getSignature
    }
    
    
    func toVerificationKey<T>() throws -> T where T: VerificationKey {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        var vkey =  T(
            payload: signingKey.verifyKey.bytes,
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
        vkey._payload = signingKey.verifyKey.bytes
        return vkey        
    }

    
    static func generate() throws -> Self {
        let signingKey = try SwiftNcal.SigningKey.generate()
        var sKey = Self(payload: signingKey.bytes)
        sKey._payload = signingKey.bytes
        return sKey
    }
}

public extension ExtendedSigningKey {
    
    func sign(data: Data) throws -> Data {        
        let privateKey = try BIP32ED25519PrivateKey(
            privateKey: payload.prefix(64),  // First 64 bytes
            chainCode: payload.suffix(from: 96)  // From byte 96 onwards
        )
        
        let signedMessage = try privateKey.sign(message: data)
        return signedMessage
    }

    func toVerificationKey<T>() -> T where T: ExtendedVerificationKey {
        return T(
            payload: payload.suffix(from: 64),
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
    }

    static func fromHDWallet(_ hdwallet: HDWallet) throws -> any ExtendedSigningKey {
        let payload = hdwallet.xPrivateKey + hdwallet.publicKey + hdwallet.chainCode
        
        return Self(
            payload: payload,
            type: "PaymentExtendedSigningKeyShelley_ed25519_bip32",
            description: "Payment Signing Key"
        )
    }
}

public enum SigningKeyType: Codable, Equatable, Hashable {

    case extendedSigningKey(any ExtendedSigningKey)
    case signingKey(any SigningKey)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        if data.count == 64 {
            self = .signingKey(SKey(payload: data))
        } else {
            self = .extendedSigningKey(ExtendedSKey(payload: data))
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
                } else if let skey = key as? ExtendedSKey {
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
                } else if let skey = key as? SKey {
                    return try skey.sign(data: data)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
        }
    }
    
    public func toVerificationKey() throws -> any VerificationKey {
        switch self {
            case .extendedSigningKey(let key):
                if let skey = key as? PaymentExtendedSigningKey {
                    let evkey: PaymentExtendedVerificationKey = skey.toVerificationKey()
                    let vkey: PaymentVerificationKey = evkey.toNonExtended()
                    return vkey
                } else if let skey = key as? StakeExtendedSigningKey {
                    let evkey: StakeExtendedVerificationKey = skey.toVerificationKey()
                    let vkey: StakeVerificationKey = evkey.toNonExtended()
                    return vkey
                } else if let skey = key as? ExtendedSKey {
                    let evkey: ExtendedVKey = skey.toVerificationKey()
                    let vkey: VKey = evkey.toNonExtended()
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
                } else if let skey = key as? SKey {
                    let vkey: VKey = try skey.toVerificationKey()
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
                    let evkey: PaymentExtendedVerificationKey = skey.toVerificationKey()
                    return .extendedVerificationKey(evkey)
                } else if let skey = key as? StakeExtendedSigningKey {
                    let evkey: StakeExtendedVerificationKey = skey.toVerificationKey()
                    return .extendedVerificationKey(evkey)
                } else if let skey = key as? ExtendedSKey {
                    let evkey: ExtendedVKey = skey.toVerificationKey()
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
                } else if let skey = key as? SKey {
                    let vkey: VKey = try skey.toVerificationKey()
                    return .verificationKey(vkey)
                } else {
                    throw CardanoCoreError.invalidKeyTypeError("Invalid key type: \(key)")
                }
        }
    }
}
