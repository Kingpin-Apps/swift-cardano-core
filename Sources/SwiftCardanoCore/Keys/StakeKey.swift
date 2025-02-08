import Foundation
import PotentCBOR

struct StakeSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakeSigningKeyShelley_ed25519" }
    static var DESCRIPTION: String { "Stake Signing Key" }
    
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

struct StakeVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakeVerificationKeyShelley_ed25519" }
    static var DESCRIPTION: String { "Stake Verification Key" }
    
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

struct StakeExtendedSigningKey: ExtendedSigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakeExtendedSigningKeyShelley_ed25519_bip32" }
    static var DESCRIPTION: String { "Stake Signing Key" }
    
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

struct StakeExtendedVerificationKey: ExtendedVerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakeExtendedVerificationKeyShelley_ed25519_bip32" }
    static var DESCRIPTION: String { "Stake Verification Key" }
    
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

struct StakeKeyPair {
    let signingKey: StakeSigningKey
    let verificationKey: StakeVerificationKey
    
    init(signingKey: StakeSigningKey, verificationKey: StakeVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakeKeyPair
    static func generate() throws -> StakeKeyPair {
        let signingKey = try StakeSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakeKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: StakeSigningKey) throws -> StakeKeyPair {
        let verificationKey: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(signingKey)
        return StakeKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakeKeyPair
extension StakeKeyPair: Equatable {
    static func == (lhs: StakeKeyPair, rhs: StakeKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

