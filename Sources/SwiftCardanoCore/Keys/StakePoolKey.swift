import Foundation

class StakePoolSigningKey: SigningKey {
    class override var TYPE: String { "StakePoolSigningKey_ed25519" }
    class override var DESCRIPTION: String { "Stake Pool Operator Signing Key" }
}

class StakePoolVerificationKey: VerificationKey {
    class override var TYPE: String { "StakePoolVerificationKey_ed25519" }
    class override var DESCRIPTION: String { "Stake Pool Operator Verification Key" }
}

class StakePoolKeyPair {
    let signingKey: StakePoolSigningKey
    let verificationKey: StakePoolVerificationKey
    
    init(signingKey: StakePoolSigningKey, verificationKey: StakePoolVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // Class method to generate a new StakePoolKeyPair
    class func generate() throws -> StakePoolKeyPair {
        let signingKey = try StakePoolSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // Create a StakePoolKeyPair from an existing signing key
    class func fromSigningKey(_ signingKey: StakePoolSigningKey) throws -> StakePoolKeyPair {
        let verificationKey: StakePoolVerificationKey = try StakePoolVerificationKey.fromSigningKey(signingKey) 
        return StakePoolKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakePoolKeyPair
extension StakePoolKeyPair: Equatable {
    static func == (lhs: StakePoolKeyPair, rhs: StakePoolKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
