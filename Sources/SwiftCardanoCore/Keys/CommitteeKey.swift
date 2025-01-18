import Foundation

class CommitteeColdSigningKey: SigningKey {
    class override var TYPE: String { "ConstitutionalCommitteeColdSigningKey_ed25519" }
    class override var DESCRIPTION: String { "Constitutional Committee Cold Signing Key" }
}

class CommitteeColdVerificationKey: VerificationKey {
    class override var TYPE: String { "ConstitutionalCommitteeColdVerificationKey_ed25519" }
    class override var DESCRIPTION: String { "Constitutional Committee Cold Verification Key" }
}


class CommitteeHotSigningKey: SigningKey {
    class override var TYPE: String { "ConstitutionalCommitteeHotSigningKey_ed25519" }
    class override var DESCRIPTION: String { "Constitutional Committee Hot Signing Key" }
}

class CommitteeHotVerificationKey: VerificationKey {
    class override var TYPE: String { "ConstitutionalCommitteeHotVerificationKey_ed25519" }
    class override var DESCRIPTION: String { "Constitutional Committee Hot Verification Key" }
}

class CommitteeColdKeyPair {
    let signingKey: CommitteeColdSigningKey
    let verificationKey: CommitteeColdVerificationKey
    
    init(signingKey: CommitteeColdSigningKey, verificationKey: CommitteeColdVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // Class method to generate a new CommitteeColdKeyPair
    class func generate() throws -> CommitteeColdKeyPair {
        let signingKey = try CommitteeColdSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // Create a CommitteeColdKeyPair from an existing signing key
    class func fromSigningKey(_ signingKey: CommitteeColdSigningKey) throws -> CommitteeColdKeyPair {
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

class CommitteeHotKeyPair {
    let signingKey: CommitteeHotSigningKey
    let verificationKey: CommitteeHotVerificationKey
    
    init(signingKey: CommitteeHotSigningKey, verificationKey: CommitteeHotVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // Class method to generate a new CommitteeHotKeyPair
    class func generate() throws -> CommitteeHotKeyPair {
        let signingKey = try CommitteeHotSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // Create a PaymentKeyPair from an existing signing key
    class func fromSigningKey(_ signingKey: CommitteeHotSigningKey) throws -> CommitteeHotKeyPair {
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

