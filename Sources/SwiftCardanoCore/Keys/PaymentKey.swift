import Foundation

class PaymentSigningKey: SigningKey {
    class override var TYPE: String { "PaymentSigningKeyShelley_ed25519" }
    class override var DESCRIPTION: String { "Payment Signing Key" }
}

class PaymentVerificationKey: VerificationKey {
    class override var TYPE: String { "PaymentVerificationKeyShelley_ed25519" }
    class override var DESCRIPTION: String { "Payment Verification Key" }
}

class PaymentExtendedSigningKey: ExtendedSigningKey {
    class override var TYPE: String { "PaymentExtendedSigningKeyShelley_ed25519_bip32" }
    class override var DESCRIPTION: String { "Payment Signing Key" }
}

class PaymentExtendedVerificationKey: ExtendedVerificationKey {
    class override var TYPE: String { "PaymentExtendedVerificationKeyShelley_ed25519_bip32" }
    class override var DESCRIPTION: String { "Payment Verification Key" }
}

class PaymentKeyPair {
    let signingKey: PaymentSigningKey
    let verificationKey: PaymentVerificationKey
    
    init(signingKey: PaymentSigningKey, verificationKey: PaymentVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // Class method to generate a new PaymentKeyPair
    class func generate() throws -> PaymentKeyPair {
        let signingKey = try PaymentSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // Create a PaymentKeyPair from an existing signing key
    class func fromSigningKey(_ signingKey: PaymentSigningKey) throws -> PaymentKeyPair {
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
