import Foundation
import PotentCBOR


/// A PaymentSigningKey is a type of ``SigningKey`` 
public struct PaymentSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentSigningKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Payment Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// A PaymentVerificationKey is a type of ``VerificationKey``
public struct PaymentVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentVerificationKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Payment Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if payload.count > 32, let payloadData = try? CBORDecoder().decode(
            Data.self,
            from: payload
        ) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct PaymentExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentExtendedSigningKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Payment Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct PaymentExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "PaymentExtendedVerificationKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Payment Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if payload.count > 64, let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct PaymentKeyPair {
    public let signingKey: PaymentSigningKey
    public let verificationKey: PaymentVerificationKey
    
    public init(signingKey: PaymentSigningKey, verificationKey: PaymentVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new PaymentKeyPair
    public static func generate() throws -> PaymentKeyPair {
        let signingKey = try PaymentSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: PaymentSigningKey) throws -> PaymentKeyPair {
        let verificationKey: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(signingKey)
        return PaymentKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension PaymentKeyPair: Equatable {
    public static func == (lhs: PaymentKeyPair, rhs: PaymentKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
