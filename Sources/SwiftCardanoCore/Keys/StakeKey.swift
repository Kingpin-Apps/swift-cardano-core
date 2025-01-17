import Foundation

class StakeSigningKey: SigningKey {
    class override var TYPE: String { "StakeSigningKeyShelley_ed25519" }
    class override var DESCRIPTION: String { "Stake Signing Key" }
}

class StakeVerificationKey: VerificationKey {
    class override var TYPE: String { "StakeVerificationKeyShelley_ed25519" }
    class override var DESCRIPTION: String { "Stake Verification Key" }
}

class StakeExtendedSigningKey: ExtendedSigningKey {
    class override var TYPE: String { "StakeExtendedSigningKeyShelley_ed25519_bip32" }
    class override var DESCRIPTION: String { "Stake Signing Key" }
}

class StakeExtendedVerificationKey: ExtendedVerificationKey {
    class override var TYPE: String { "StakeExtendedVerificationKeyShelley_ed25519_bip32" }
    class override var DESCRIPTION: String { "Stake Verification Key" }
}

class StakeKeyPair {
    let signingKey: StakeSigningKey
    let verificationKey: StakeVerificationKey
    
    init(signingKey: StakeSigningKey, verificationKey: StakeVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // Class method to generate a new StakeKeyPair
    class func generate() throws -> StakeKeyPair {
        let signingKey = try StakeSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // Create a StakeKeyPair from an existing signing key
    class func fromSigningKey(_ signingKey: StakeSigningKey) throws -> StakeKeyPair {
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

