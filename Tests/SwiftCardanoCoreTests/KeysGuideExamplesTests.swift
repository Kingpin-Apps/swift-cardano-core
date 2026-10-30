import Foundation
import Testing
import SwiftCardanoCore

/// The code examples of the Keys guide (`Keys.md`), compiled and run so that
/// the guide stays true to the API. Each test holds one example as the guide
/// shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Keys guide examples")
struct KeysGuideExamplesTests {
    /// Stand-ins for values the guide assumes the reader already has.
    let paymentKeyPair = try! PaymentKeyPair.generate()
    let stakeKeyPair = try! StakeKeyPair.generate()
    let paymentSKey = try! PaymentSigningKey.generate()
    let txBody = TransactionBody(
        inputs: .list([TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)]),
        outputs: [],
        fee: 200_000)
    var txBodyHash: Data { try! txBody.hash() }

    @Test func generatingKeys() throws {
        // Individual key generation
        let paymentSKey = try PaymentSigningKey.generate()
        let paymentVKey: PaymentVerificationKey = try paymentSKey.toVerificationKey()

        let stakeSKey = try StakeSigningKey.generate()
        let stakeVKey: StakeVerificationKey = try stakeSKey.toVerificationKey()

        // KeyPair generation (recommended)
        let paymentKeyPair = try PaymentKeyPair.generate()
        let stakeKeyPair = try StakeKeyPair.generate()

        print("Payment Key Generated: \(paymentKeyPair.verificationKey.payload.toHex)")
        print("Stake Key Generated: \(stakeKeyPair.verificationKey.payload.toHex)")
        _ = (paymentVKey, stakeVKey)
    }

    @Test(.disabled("Writes key files to the working directory"))
    func keyPersistence() throws {
        // Save keys to files (Cardano CLI compatible format)
        try paymentKeyPair.signingKey.save(to: "payment.skey")
        try paymentKeyPair.verificationKey.save(to: "payment.vkey")
        try stakeKeyPair.signingKey.save(to: "stake.skey")
        try stakeKeyPair.verificationKey.save(to: "stake.vkey")

        // Load keys from files
        let loadedPaymentSKey = try PaymentSigningKey.load(from: "payment.skey")
        let loadedPaymentVKey = try PaymentVerificationKey.load(from: "payment.vkey")
        let loadedStakeSKey = try StakeSigningKey.load(from: "stake.skey")
        let loadedStakeVKey = try StakeVerificationKey.load(from: "stake.vkey")

        // Verify loaded keys match
        #expect(loadedPaymentSKey == paymentKeyPair.signingKey)
        #expect(loadedPaymentVKey == paymentKeyPair.verificationKey)
        _ = (loadedStakeSKey, loadedStakeVKey)
    }

    @Test func keyDerivationAndValidation() throws {
        // Derive verification key from signing key
        let derivedVKey: PaymentVerificationKey = try paymentSKey.toVerificationKey()

        // Generate key hashes for addresses
        let paymentKeyHash = try paymentKeyPair.verificationKey.hash()
        let stakeKeyHash = try stakeKeyPair.verificationKey.hash()

        print("Payment Key Hash: \(paymentKeyHash.payload.toHex)")
        print("Stake Key Hash: \(stakeKeyHash.payload.toHex)")

        // Sign a message: a 64-byte Ed25519 signature
        let testData = Data("test message".utf8)
        let signature = try paymentKeyPair.signingKey.sign(data: testData)
        #expect(signature.count == 64)
        _ = derivedVKey
    }

    @Test func extendedKeys() throws {
        // Create a wallet from a new 24-word mnemonic
        let mnemonic = try HDWallet.generateMnemonic().joined(separator: " ")
        let wallet = try HDWallet.fromMnemonic(mnemonic: mnemonic)

        // Derive the first payment and stake keys of account 0 (CIP-1852)
        let paymentWallet = try wallet.derive(fromPath: "m/1852'/1815'/0'/0/0")
        let stakeWallet = try wallet.derive(fromPath: "m/1852'/1815'/0'/2/0")

        let extendedPaymentKey = try PaymentExtendedSigningKey.fromHDWallet(paymentWallet)
        let extendedStakeKey = try StakeExtendedSigningKey.fromHDWallet(stakeWallet)

        // The extended verification key carries the chain code
        let extendedPaymentVKey: PaymentExtendedVerificationKey = try extendedPaymentKey.toVerificationKey()
        _ = (extendedStakeKey, extendedPaymentVKey)
    }

    @Test func specializedKeys() throws {
        // Stake pool keys
        let poolKeyPair = try StakePoolKeyPair.generate()
        let vrfKeyPair = try VRFKeyPair.generate()

        // Pool key hash for registration
        let poolKeyHash = try poolKeyPair.verificationKey.poolKeyHash()
        let vrfKeyHash = try vrfKeyPair.verificationKey.hash()

        // DRep keys for governance
        let drepKeyPair = try DRepKeyPair.generate()
        let drepKeyHash = try drepKeyPair.verificationKey.hash()

        // Committee keys
        let committeeColdKeyPair = try CommitteeColdKeyPair.generate()
        let committeeHotKeyPair = try CommitteeHotKeyPair.generate()
        _ = (poolKeyHash, vrfKeyHash, drepKeyHash, committeeColdKeyPair, committeeHotKeyPair)
    }

    @Test func keySecurity() throws {
        // Secure key generation with entropy
        func generateSecureKeyPair() throws -> PaymentKeyPair {
            // SwiftCardanoCore uses secure random number generation internally
            return try PaymentKeyPair.generate()
        }

        // Key validation: the verification key must be the one the signing key derives
        func validateKeyPair(_ keyPair: PaymentKeyPair) throws -> Bool {
            let derived = try PaymentKeyPair.fromSigningKey(keyPair.signingKey)
            return derived.verificationKey == keyPair.verificationKey
        }

        #expect(try validateKeyPair(paymentKeyPair))
        #expect(try validateKeyPair(generateSecureKeyPair()))
    }

    @Test func transactionSigning() throws {
        // Sign transaction data
        let txBodyHash = try txBody.hash()
        let signature = try paymentKeyPair.signingKey.sign(data: txBodyHash)

        // Create witness for transaction
        let witness = VerificationKeyWitness(
            vkey: .verificationKey(paymentKeyPair.verificationKey),
            signature: signature
        )
        _ = try witness.toCBORData()
    }

    @Test func multiSignatureSetup() throws {
        // Generate multiple key pairs for multi-sig
        let keyPairs = try (0..<3).map { _ in try PaymentKeyPair.generate() }
        let keyHashes = try keyPairs.map { try $0.verificationKey.hash() }

        // Create multi-signature script (2-of-3)
        let multiSigScript = NativeScript.scriptNofK(ScriptNofK(
            required: 2,
            scripts: keyHashes.map { keyHash in
                .scriptPubkey(ScriptPubkey(keyHash: keyHash))
            }
        ))

        // Sign with multiple keys
        let signatures = try keyPairs.map { keyPair in
            try keyPair.signingKey.sign(data: txBodyHash)
        }
        _ = (multiSigScript, signatures)
    }

    @Test(.disabled("Writes a key file to the working directory"))
    func errorHandling() throws {
        do {
            let keyPair = try PaymentKeyPair.generate()
            try keyPair.signingKey.save(to: "payment.skey")

            let signature = try keyPair.signingKey.sign(data: Data("test message".utf8))
            print("Signature: \(signature.toHex)")
        } catch {
            print("Key operation error: \(error)")
        }
    }

    @Test(.disabled("Writes a key file to the working directory"))
    func secureKeyStorage() throws {
        // Store keys securely with proper file permissions
        func saveKeySecurely<T: SigningKeyProtocol>(_ key: T, to path: String) throws {
            try key.save(to: path)

            // Set restrictive file permissions (Unix-like systems)
            let fileURL = URL(fileURLWithPath: path)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], // Owner read/write only
                ofItemAtPath: fileURL.path
            )
        }

        try saveKeySecurely(paymentKeyPair.signingKey, to: "secure_payment.skey")
    }

    @Test func testingAndValidation() throws {
        // Key generation testing
        func testKeyGeneration() throws {
            let keyPair1 = try PaymentKeyPair.generate()
            let keyPair2 = try PaymentKeyPair.generate()

            // Keys should be different
            #expect(keyPair1.signingKey != keyPair2.signingKey)
            #expect(keyPair1.verificationKey != keyPair2.verificationKey)

            // Derived verification key should match
            let derivedVKey: PaymentVerificationKey = try keyPair1.signingKey.toVerificationKey()
            #expect(derivedVKey == keyPair1.verificationKey)
        }

        // Round-trip serialization testing
        func testKeySerialization() throws {
            let originalKey = try PaymentSigningKey.generate()

            // Serialize and deserialize
            let serialized = try originalKey.toCBORData()
            let deserialized = try PaymentSigningKey.fromCBOR(data: serialized)

            // Should be identical
            #expect(originalKey == deserialized)
        }

        try testKeyGeneration()
        try testKeySerialization()
    }
}
