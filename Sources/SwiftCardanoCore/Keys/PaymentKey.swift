import Foundation
import PotentCBOR

struct PaymentSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "PaymentSigningKeyShelley_ed25519" }
    static var DESCRIPTION: String { "Payment Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct PaymentVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "PaymentVerificationKeyShelley_ed25519" }
    static var DESCRIPTION: String { "Payment Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct PaymentExtendedSigningKey: ExtendedSigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "PaymentExtendedSigningKeyShelley_ed25519_bip32" }
    static var DESCRIPTION: String { "Payment Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct PaymentExtendedVerificationKey: ExtendedVerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "PaymentExtendedVerificationKeyShelley_ed25519_bip32" }
    static var DESCRIPTION: String { "Payment Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct PaymentKeyPair {
    let signingKey: PaymentSigningKey
    let verificationKey: PaymentVerificationKey
    
    init(signingKey: PaymentSigningKey, verificationKey: PaymentVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new PaymentKeyPair
    static func generate() throws -> PaymentKeyPair {
        let signingKey = try PaymentSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: PaymentSigningKey) throws -> PaymentKeyPair {
        let verificationKey: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(signingKey)
        return PaymentKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension PaymentKeyPair: Equatable {
    static func == (lhs: PaymentKeyPair, rhs: PaymentKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
