import Foundation
import PotentCBOR

struct CommitteeColdSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "ConstitutionalCommitteeColdSigningKey_ed25519" }
    static var DESCRIPTION: String { "Constitutional Committee Cold Signing Key" }
    
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

struct CommitteeColdVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "ConstitutionalCommitteeColdVerificationKey_ed25519" }
    static var DESCRIPTION: String { "Constitutional Committee Cold Verification Key" }
    
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


struct CommitteeHotSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "ConstitutionalCommitteeHotSigningKey_ed25519" }
    static var DESCRIPTION: String { "Constitutional Committee Hot Signing Key" }
    
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

struct CommitteeHotVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "ConstitutionalCommitteeHotVerificationKey_ed25519" }
    static var DESCRIPTION: String { "Constitutional Committee Hot Verification Key" }
    
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

struct CommitteeColdKeyPair {
    let signingKey: CommitteeColdSigningKey
    let verificationKey: CommitteeColdVerificationKey
    
    init(signingKey: CommitteeColdSigningKey, verificationKey: CommitteeColdVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeColdKeyPair
    static func generate() throws -> CommitteeColdKeyPair {
        let signingKey = try CommitteeColdSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a CommitteeColdKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: CommitteeColdSigningKey) throws -> CommitteeColdKeyPair {
        let verificationKey: CommitteeColdVerificationKey = try CommitteeColdVerificationKey.fromSigningKey(signingKey)
        return CommitteeColdKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension CommitteeColdKeyPair: Equatable {
    static func == (lhs: CommitteeColdKeyPair, rhs: CommitteeColdKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

struct CommitteeHotKeyPair {
    let signingKey: CommitteeHotSigningKey
    let verificationKey: CommitteeHotVerificationKey
    
    init(signingKey: CommitteeHotSigningKey, verificationKey: CommitteeHotVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeHotKeyPair
    static func generate() throws -> CommitteeHotKeyPair {
        let signingKey = try CommitteeHotSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: CommitteeHotSigningKey) throws -> CommitteeHotKeyPair {
        let verificationKey: CommitteeHotVerificationKey = try CommitteeHotVerificationKey.fromSigningKey(signingKey)
        return CommitteeHotKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for CommitteeHotKeyPair
extension CommitteeHotKeyPair: Equatable {
    static func == (lhs: CommitteeHotKeyPair, rhs: CommitteeHotKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

