import Foundation
import PotentCBOR

struct DRepSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "DRepSigningKey_ed25519" }
    static var DESCRIPTION: String { "Delegated Representative Signing Key" }
    
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

struct DRepVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "DRepVerificationKey_ed25519" }
    static var DESCRIPTION: String { "Delegated Representative Verification Key" }
    
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

struct DRepKeyPair {
    let signingKey: DRepSigningKey
    let verificationKey: DRepVerificationKey
    
    init(signingKey: DRepSigningKey, verificationKey: DRepVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new DRepKeyPair
    static func generate() throws -> DRepKeyPair {
        let signingKey = try DRepSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a DRepKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: DRepSigningKey) throws -> DRepKeyPair {
        let verificationKey: DRepVerificationKey = try DRepVerificationKey.fromSigningKey(signingKey)
        return DRepKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension DRepKeyPair: Equatable {
    static func == (lhs: DRepKeyPair, rhs: DRepKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
