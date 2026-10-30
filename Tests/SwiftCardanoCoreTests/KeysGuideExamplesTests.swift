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
        let paymentVKey = try PaymentVerificationKey.fromSigningKey(paymentSKey)

        let stakeSKey = try StakeSigningKey.generate()
        let stakeVKey = try StakeVerificationKey.fromSigningKey(stakeSKey)

        // KeyPair generation (recommended)
        let paymentKeyPair = try PaymentKeyPair.generate()
        let stakeKeyPair = try StakeKeyPair.generate()

        print("Payment Key Generated: \(paymentKeyPair.verificationKey.payload.toHex)")
        print("Stake Key Generated: \(stakeKeyPair.verificationKey.payload.toHex)")

        // fromSigningKey infers its type and derives the key the signing key does.
        #expect(paymentVKey == (try paymentSKey.toVerificationKey() as PaymentVerificationKey))
        #expect(stakeVKey == (try stakeSKey.toVerificationKey() as StakeVerificationKey))
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
        let derivedVKey = try PaymentVerificationKey.fromSigningKey(paymentSKey)

        // Generate key hashes for addresses
        let paymentKeyHash = try paymentKeyPair.verificationKey.hash()
        let stakeKeyHash = try stakeKeyPair.verificationKey.hash()

        print("Payment Key Hash: \(paymentKeyHash.payload.toHex)")
        print("Stake Key Hash: \(stakeKeyHash.payload.toHex)")

        // Sign a message (a 64-byte Ed25519 signature) and verify the signature
        let testData = Data("test message".utf8)
        let signature = try paymentKeyPair.signingKey.sign(data: testData)
        let isValid = try paymentKeyPair.verificationKey.verify(signature: signature, data: testData)
        #expect(isValid)

        // A signature does not verify for any other message
        let isTampered = try paymentKeyPair.verificationKey.verify(
            signature: signature,
            data: Data("tampered message".utf8)
        )
        #expect(!isTampered)

        #expect(signature.count == 64)
        #expect(derivedVKey == (try paymentSKey.toVerificationKey() as PaymentVerificationKey))
        // Another key's signature, or a tampered one, does not verify.
        #expect(try !stakeKeyPair.verificationKey.verify(signature: signature, data: testData))
        var tamperedSignature = signature
        tamperedSignature[0] ^= 0x01
        #expect(try !paymentKeyPair.verificationKey.verify(signature: tamperedSignature, data: testData))
        // The verification key inside a witness verifies too.
        let vkey = VerificationKeyType.verificationKey(paymentKeyPair.verificationKey)
        #expect(try vkey.verify(signature: signature, data: testData))
        // A key that is not 32 bytes cannot check an Ed25519 signature.
        let badKey = try PaymentVerificationKey(payload: Data([1, 2, 3]))
        let error = #expect(throws: CardanoCoreError.self) {
            try badKey.verify(signature: signature, data: testData)
        }
        guard case .invalidKeyTypeError = error else {
            Issue.record("Expected invalidKeyTypeError, got \(String(describing: error))")
            return
        }
    }

    @Test func generatingExtendedKeys() throws {
        // Generate extended keys
        let rootPaymentSKey = try PaymentExtendedSigningKey.generate()
        let rootStakeSKey = try StakeExtendedSigningKey.generate()

        // Their verification keys carry the chain code
        let rootPaymentVKey = try PaymentExtendedVerificationKey.fromSigningKey(rootPaymentSKey)
        let rootStakeVKey = try StakeExtendedVerificationKey.fromSigningKey(rootStakeSKey)

        // Extended keys sign and verify like the others
        let message = Data("extended message".utf8)
        let rootSignature = try rootPaymentSKey.sign(data: message)
        #expect(try rootPaymentVKey.verify(signature: rootSignature, data: message))

        #expect(try !rootPaymentVKey.verify(signature: rootSignature, data: Data("other".utf8)))
        #expect(rootPaymentVKey.payload.count == 64)
        #expect(rootStakeVKey.payload.count == 64)
        #expect(rootPaymentSKey != (try PaymentExtendedSigningKey.generate()))
        // Each key is labelled with its own type.
        #expect(rootPaymentSKey.type.hasPrefix("PaymentExtendedSigningKey"))
        #expect(rootStakeSKey.type.hasPrefix("StakeExtendedSigningKey"))
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
        let extendedPaymentVKey = try PaymentExtendedVerificationKey.fromSigningKey(extendedPaymentKey)

        #expect(extendedPaymentVKey.payload.count == 64)
        // fromHDWallet returns the concrete key type, labelled with its own type.
        #expect(extendedStakeKey.type.hasPrefix("StakeExtendedSigningKey"))
        #expect(extendedPaymentKey.type.hasPrefix("PaymentExtendedSigningKey"))
        let message = Data("derived message".utf8)
        #expect(try extendedPaymentVKey.verify(signature: extendedPaymentKey.sign(data: message), data: message))
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

        // Key validation: the verification key must verify the signing key's signatures
        func validateKeyPair(_ keyPair: PaymentKeyPair) throws {
            let testMessage = Data("validation test".utf8)
            let signature = try keyPair.signingKey.sign(data: testMessage)

            guard try keyPair.verificationKey.verify(signature: signature, data: testMessage) else {
                throw CardanoCoreError.invalidArgument("Key pair validation failed")
            }
        }

        try validateKeyPair(paymentKeyPair)

        try validateKeyPair(generateSecureKeyPair())
        // A pair whose keys do not belong together fails validation.
        let mismatched = PaymentKeyPair(
            signingKey: paymentKeyPair.signingKey,
            verificationKey: try PaymentKeyPair.generate().verificationKey)
        #expect(throws: CardanoCoreError.invalidArgument("Key pair validation failed")) {
            try validateKeyPair(mismatched)
        }
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
        } catch CardanoCoreError.ioError(let message) {
            print("File operation failed: \(message ?? "")")
        } catch CardanoCoreError.invalidKeyTypeError(let message) {
            print("Wrong kind of key: \(message ?? "")")
        } catch {
            print("Key operation error: \(error)")
        }
    }

    /// The error handling example's `ioError` case is the one `save(to:)`
    /// throws when the file exists; run here in a temporary directory.
    @Test func errorHandlingCatchesAnExistingFile() throws {
        let path = NSTemporaryDirectory() + "keys-guide-\(UUID().uuidString).skey"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let keyPair = try PaymentKeyPair.generate()
        try keyPair.signingKey.save(to: path)

        var caught: String?
        do {
            try keyPair.signingKey.save(to: path)
        } catch CardanoCoreError.ioError(let message) {
            caught = message
        }
        #expect(caught?.hasPrefix("File already exists") == true)
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
            let derivedVKey = try PaymentVerificationKey.fromSigningKey(keyPair1.signingKey)
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
