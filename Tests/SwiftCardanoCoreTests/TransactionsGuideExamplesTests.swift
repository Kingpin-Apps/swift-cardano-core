import Foundation
import Testing
import SwiftCardanoCore

/// The code examples of the Transactions guide (`Transactions.md`), compiled
/// and run so that the guide stays true to the API. Each test holds one
/// example as the guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Transactions guide examples")
struct TransactionsGuideExamplesTests {
    // Stand-ins for the values earlier examples of the guide build.
    let txInput = TransactionInput(
        transactionId: try! TransactionId(from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5")),
        index: 0)
    let recipientAddress = try! Address.fromBech32("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x")
    let policyId = try! ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc"))
    let assetName = AssetName(from: "MyToken")
    var output: TransactionOutput { TransactionOutput(address: recipientAddress, amount: Value(coin: 1_500_000)) }
    var outputWithAssets: TransactionOutput {
        TransactionOutput(
            address: recipientAddress,
            amount: Value(coin: 2_000_000, multiAsset: MultiAsset([policyId: Asset([assetName: 1000])])))
    }
    var txBody: TransactionBody {
        TransactionBody(inputs: .orderedSet(try! OrderedSet([txInput])), outputs: [output, outputWithAssets], fee: Coin(200_000), ttl: 1000000)
    }
    let paymentKeyPair = try! PaymentKeyPair.generate()
    var witness: VerificationKeyWitness {
        VerificationKeyWitness(
            vkey: .verificationKey(paymentKeyPair.verificationKey),
            signature: try! paymentKeyPair.signingKey.sign(data: txBody.hash()))
    }
    var witnessSet: TransactionWitnessSet {
        TransactionWitnessSet(vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])))
    }
    var transaction: Transaction { Transaction(transactionBody: txBody, transactionWitnessSet: witnessSet) }

    @Test func createTransactionInputs() throws {
        // Reference a UTxO to spend
        let txId = try TransactionId(from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"))
        let txInput = TransactionInput(transactionId: txId, index: 0)
        _ = txInput
    }

    @Test func createTransactionOutputs() throws {
        // Create a basic ADA output
        let recipientAddress = try Address.fromBech32("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x")
        let amount = Value(coin: 1_500_000) // 1.5 ADA
        let output = TransactionOutput(address: recipientAddress, amount: amount)

        // Create an output with native assets
        let policyId = try ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc"))
        let assetName = AssetName(from: "MyToken")
        let asset = Asset([assetName: 1000])
        let multiAsset = MultiAsset([policyId: asset])
        let valueWithAssets = Value(coin: 2_000_000, multiAsset: multiAsset)
        let outputWithAssets = TransactionOutput(address: recipientAddress, amount: valueWithAssets)
        _ = (output, outputWithAssets)
    }

    @Test func buildTransactionBody() throws {
        let txBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([txInput])),
            outputs: [output, outputWithAssets],
            fee: Coin(200_000), // 0.2 ADA fee
            ttl: 1000000 // Time to live (optional)
        )
        _ = try txBody.toCBORData()
    }

    @Test func signTheTransaction() throws {
        // Generate or load signing keys
        let paymentKeyPair = try PaymentKeyPair.generate()

        // Sign the transaction body hash
        let signature = try paymentKeyPair.signingKey.sign(data: txBody.hash())

        // Create witness
        let witness = VerificationKeyWitness(
            vkey: .verificationKey(paymentKeyPair.verificationKey),
            signature: signature
        )

        // Create witness set
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness]))
        )
        _ = try witnessSet.toCBORData()
    }

    @Test func completeTransaction() throws {
        let transaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: witnessSet,
            valid: true // Mark as valid
        )

        // Get transaction ID
        let transactionId = transaction.id
        print("Transaction ID: \(transactionId?.payload.toHex ?? "unknown")")
        #expect(transactionId != nil)
    }

    @Test func slotsAndTime() {
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: 4_492_800) == 1596059091000)
        #expect(SlotTimeline.mainnet.slot(atMilliseconds: 1_596_059_091_000) == 4492800)
    }

    @Test func multiSignatureTransactions() throws {
        // Create multiple witnesses for multi-sig
        let keyPair1 = try PaymentKeyPair.generate()
        let keyPair2 = try PaymentKeyPair.generate()

        let signature1 = try keyPair1.signingKey.sign(data: txBody.hash())
        let signature2 = try keyPair2.signingKey.sign(data: txBody.hash())

        let witness1 = VerificationKeyWitness(
            vkey: .verificationKey(keyPair1.verificationKey),
            signature: signature1
        )

        let witness2 = VerificationKeyWitness(
            vkey: .verificationKey(keyPair2.verificationKey),
            signature: signature2
        )

        let multiSigWitnessSet = TransactionWitnessSet(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness1, witness2]))
        )
        #expect(multiSigWitnessSet.vkeyWitnesses?.count == 2)
    }

    @Test func scriptTransactions() throws {
        // Add native script to witness set
        let keyHash = try paymentKeyPair.verificationKey.hash()
        let nativeScript = NativeScript.scriptPubkey(ScriptPubkey(keyHash: keyHash))

        let scriptWitnessSet = TransactionWitnessSet(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
            nativeScripts: .nonEmptyOrderedSet(NonEmptyOrderedSet([nativeScript]))
        )
        _ = try scriptWitnessSet.toCBORData()
    }

    @Test func mintingTransactions() throws {
        // Create minting policy and assets
        let mintingAmount: Int64 = 1000
        let mintingAsset = Asset([assetName: mintingAmount])
        let mintingValue = MultiAsset([policyId: mintingAsset])

        // Add minting to transaction body
        let mintingTxBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([txInput])),
            outputs: [outputWithAssets],
            fee: Coin(250_000), // Higher fee for minting
            mint: mintingValue // Assets to mint
        )
        _ = try mintingTxBody.toCBORData()
    }

    @Test func serializeAndDeserialize() throws {
        // Convert to CBOR bytes
        let cborData = try transaction.toCBORData()

        // Convert to CBOR hex string
        let cborHex = try transaction.toCBORHex()
        print("CBOR: \(cborHex)")

        // From CBOR data
        let restoredTransaction = try Transaction.fromCBOR(data: cborData)

        // From CBOR hex string
        let transactionFromHex = try Transaction.fromCBORHex(cborHex)

        #expect(restoredTransaction.id == transaction.id)
        #expect(transactionFromHex.id == transaction.id)
    }

    @Test(.disabled("Writes transaction files to the working directory"))
    func saveAndLoadMethods() throws {
        // Create a complete transaction
        let transaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: witnessSet,
            valid: true
        )

        // Save transaction to file
        try transaction.save(to: "transaction.json")
        print("Transaction saved to transaction.json")

        // Load transaction from file
        let loadedTransaction = try Transaction.load(from: "transaction.json")
        print("Transaction loaded successfully")

        // Verify they match
        #expect(transaction.id == loadedTransaction.id)
    }

    @Test(.disabled("Writes transaction files to the working directory"))
    func fileFormatCompatibility() throws {
        let scriptWitnessSet = witnessSet
        let mintingTxBody = txBody

        // Save different transaction types
        let simpleTransaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: witnessSet
        )

        let scriptTransaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: scriptWitnessSet
        )

        let mintingTransaction = Transaction(
            transactionBody: mintingTxBody,
            transactionWitnessSet: witnessSet
        )

        // Save transactions to files
        try simpleTransaction.save(to: "simple-tx.json")
        try scriptTransaction.save(to: "script-tx.json")
        try mintingTransaction.save(to: "minting-tx.json")

        // These files can be used with cardano-cli commands
        // For example: cardano-cli transaction submit --tx-file simple-tx.json
    }

    @Test(.disabled("Reads transaction files from the working directory"))
    func workingWithTransactionFiles() throws {
        // Load and inspect transaction details
        func inspectTransaction(from filename: String) throws {
            let transaction = try Transaction.load(from: filename)

            print("Transaction ID: \(transaction.id?.payload.toHex ?? "unknown")")
            print("Number of inputs: \(transaction.transactionBody.inputs.count)")
            print("Number of outputs: \(transaction.transactionBody.outputs.count)")
            print("Fee: \(transaction.transactionBody.fee) lovelace")

            if let ttl = transaction.transactionBody.ttl {
                print("Time to live: \(ttl)")
            }

            if let mint = transaction.transactionBody.mint {
                print("Minting \(mint.count) asset types")
            }

            if let certificates = transaction.transactionBody.certificates {
                print("Contains \(certificates.count) certificates")
            }

            if let witnesses = transaction.transactionWitnessSet.vkeyWitnesses {
                print("Signed by \(witnesses.count) keys")
            }
        }

        // Usage
        try inspectTransaction(from: "simple-tx.json")
        try inspectTransaction(from: "minting-tx.json")
    }
}
