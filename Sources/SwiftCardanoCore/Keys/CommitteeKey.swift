import Foundation
import PotentCBOR

public struct CommitteeColdSigningKey: SigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeColdSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Cold Signing Key" }
    
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

public struct CommitteeColdVerificationKey: VerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeColdVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Cold Verification Key" }
    
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


public struct CommitteeHotSigningKey: SigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeHotSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Hot Signing Key" }
    
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

public struct CommitteeHotVerificationKey: VerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeHotVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Hot Verification Key" }
    
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

public struct CommitteeColdKeyPair {
    public let signingKey: CommitteeColdSigningKey
    public let verificationKey: CommitteeColdVerificationKey
    
    public init(signingKey: CommitteeColdSigningKey, verificationKey: CommitteeColdVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeColdKeyPair
    public static func generate() throws -> CommitteeColdKeyPair {
        let signingKey = try CommitteeColdSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a CommitteeColdKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: CommitteeColdSigningKey) throws -> CommitteeColdKeyPair {
        let verificationKey: CommitteeColdVerificationKey = try CommitteeColdVerificationKey.fromSigningKey(signingKey)
        return CommitteeColdKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension CommitteeColdKeyPair: Equatable {
    public static func == (lhs: CommitteeColdKeyPair, rhs: CommitteeColdKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

public struct CommitteeHotKeyPair {
    public let signingKey: CommitteeHotSigningKey
    public let verificationKey: CommitteeHotVerificationKey
    
    public init(signingKey: CommitteeHotSigningKey, verificationKey: CommitteeHotVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeHotKeyPair
    public static func generate() throws -> CommitteeHotKeyPair {
        let signingKey = try CommitteeHotSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: CommitteeHotSigningKey) throws -> CommitteeHotKeyPair {
        let verificationKey: CommitteeHotVerificationKey = try CommitteeHotVerificationKey.fromSigningKey(signingKey)
        return CommitteeHotKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for CommitteeHotKeyPair
extension CommitteeHotKeyPair: Equatable {
    public static func == (lhs: CommitteeHotKeyPair, rhs: CommitteeHotKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

