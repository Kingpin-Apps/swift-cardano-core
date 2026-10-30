import Foundation
import OrderedCollections
import Testing
@testable import SwiftCardanoCore

/// The code examples of the Scripts guide (`Scripts.md`), compiled and run so
/// that the guide stays true to the API. Each test holds one example as the
/// guide shows it.
@Suite("Scripts guide examples")
struct ScriptsGuideExamplesTests {
    /// Stand-ins for values the guide assumes the reader already has.
    let txInput = TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)
    let scriptRefTxId = TransactionId(payload: Data(repeating: 2, count: 32))
    let recipientAddress = try! Address(
        paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 3, count: 28))),
        network: .testnet)

    @Test func simpleSignatureScript() throws {
        // Generate keys
        let keyPair = try PaymentKeyPair.generate()
        let keyHash = try keyPair.verificationKey.hash()

        // Create signature script
        let sigScript = NativeScript.scriptPubkey(ScriptPubkey(keyHash: keyHash))

        // Calculate script hash (policy ID)
        let scriptHash = try sigScript.scriptHash()
        print("Script Hash/Policy ID: \(scriptHash.payload.toHex)")
    }

    @Test func multiSignatureScript() throws {
        // Generate multiple keys
        let keyHash1 = try PaymentKeyPair.generate().verificationKey.hash()
        let keyHash2 = try PaymentKeyPair.generate().verificationKey.hash()
        let keyHash3 = try PaymentKeyPair.generate().verificationKey.hash()

        // Create 2-of-3 multi-sig script
        let multiSigScript = NativeScript.scriptNofK(ScriptNofK(
            required: 2,
            scripts: [
                .scriptPubkey(ScriptPubkey(keyHash: keyHash1)),
                .scriptPubkey(ScriptPubkey(keyHash: keyHash2)),
                .scriptPubkey(ScriptPubkey(keyHash: keyHash3)),
            ]
        ))
        _ = try multiSigScript.scriptHash()
    }

    @Test func timeLockedScripts() throws {
        // Valid from slot 1000 on (invalid_before; cardano-cli type "after")
        let afterSlot = NativeScript.invalidBefore(BeforeScript(slot: 1000))

        // Valid only before slot 2000 (invalid_hereafter; cardano-cli type "before")
        let beforeSlot = NativeScript.invalidHereAfter(AfterScript(slot: 2000))

        // Valid from slot 1000 up to slot 2000
        let timeWindowScript = NativeScript.scriptAll(ScriptAll(scripts: [afterSlot, beforeSlot]))
        _ = try timeWindowScript.scriptHash()
    }

    @Test func complexConditionalScript() throws {
        let keyHash1 = try PaymentKeyPair.generate().verificationKey.hash()
        let keyHash2 = try PaymentKeyPair.generate().verificationKey.hash()

        // Require the primary key, or the backup key once slot 129600 is reached
        let emergencyScript = NativeScript.scriptAny(ScriptAny(scripts: [
            // Primary authentication
            .scriptPubkey(ScriptPubkey(keyHash: keyHash1)),

            // Emergency recovery: the backup key, from slot 129600 on
            .scriptAll(ScriptAll(scripts: [
                .scriptPubkey(ScriptPubkey(keyHash: keyHash2)),
                .invalidBefore(BeforeScript(slot: 129_600)),
            ])),
        ]))
        _ = try emergencyScript.scriptHash()
    }

    @Test func plutusScripts() throws {
        // Load a compiled Plutus script: its flat-encoded bytes
        let scriptBytes = Data(hexString: "4e4d01000033222220051200120011")!
        let plutusV2Script = PlutusV2Script(data: scriptBytes)

        // Calculate the script hash
        let plutusHash = try plutusScriptHash(script: .plutusV2Script(plutusV2Script))

        // Create a script reference
        let scriptRef = try ScriptRef(script: Script(script: .plutusV2Script(plutusV2Script)))
        _ = (plutusHash, scriptRef)
    }

    @Test func plutusDataAndRedeemers() throws {
        // Plutus data for the script, from cardano-cli's detailed JSON schema
        let datum = try PlutusData.fromJSON("""
        {
            "constructor": 0,
            "fields": [
                {"int": 42},
                {"bytes": "deadbeef"}
            ]
        }
        """)

        // The same value built in Swift
        let built = PlutusData.constructor(Constr(tag: 0, fields: [
            .bigInt(.int(42)),
            .bytes(try Bytes(from: Data(hexString: "deadbeef")!)),
        ]))
        #expect(datum == built)

        // A redeemer for spending the first input
        let redeemer = Redeemer(
            tag: .spend,
            index: 0,
            data: datum,
            exUnits: ExecutionUnits(mem: 1_000_000, steps: 500_000_000)
        )
        _ = redeemer
    }

    @Test func equalValuesDescribeTheSameData() throws {
        let raw = Data(repeating: 7, count: 8)
        let fromChain = PlutusData.bytes(.byteString(ByteString(bytes: raw)))
        let rebuilt = PlutusData.bytes(.boundedBytes(try BoundedBytes(bytes: raw)))

        #expect(fromChain == rebuilt)                                  // the same bytes
        #expect(try fromChain.toCBORHex() == rebuilt.toCBORHex())       // and the same CBOR
    }

    @Test func mapsKeepTheirOrder() throws {
        let a = PlutusData.bytes(try Bytes(from: Data("a".utf8)))
        let b = PlutusData.bytes(try Bytes(from: Data("b".utf8)))
        let one = PlutusData.bigInt(.int(1)), two = PlutusData.bigInt(.int(2))

        let first = PlutusData.map(MapPairs([(one, a), (two, b)]))
        let second = PlutusData.map(MapPairs([(two, b), (one, a)]))
        #expect(first != second)
        #expect(try first.hash() != second.hash())
    }

    @Test func nativeScriptWitnesses() throws {
        let keyPair1 = try PaymentKeyPair.generate()
        let keyHash1 = try keyPair1.verificationKey.hash()
        let multiSigScript = NativeScript.scriptNofK(ScriptNofK(
            required: 1, scripts: [.scriptPubkey(ScriptPubkey(keyHash: keyHash1))]))
        let txBody = TransactionBody(
            inputs: .list([txInput]),
            outputs: [TransactionOutput(address: recipientAddress, amount: Value(coin: 2_000_000))],
            fee: 200_000)

        // The script address that holds the funds
        let scriptAddress = try Address(
            paymentPart: .scriptHash(try multiSigScript.scriptHash()),
            network: .testnet
        )

        // The witness set: a signature for each key the script needs, and the script
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: .list([
                VerificationKeyWitness(
                    vkey: .verificationKey(keyPair1.verificationKey),
                    signature: try keyPair1.signingKey.sign(data: txBody.hash())
                ),
            ]),
            nativeScripts: .list([multiSigScript])
        )
        _ = (scriptAddress, witnessSet)
    }

    @Test func plutusScriptWitnesses() throws {
        let plutusV2Script = PlutusV2Script(data: Data(hexString: "4e4d01000033222220051200120011")!)
        let datum = PlutusData.bigInt(.int(42))
        let redeemer = Redeemer(
            tag: .spend, index: 0, data: datum,
            exUnits: ExecutionUnits(mem: 1_000_000, steps: 500_000_000))

        // The witness set of a transaction that runs a Plutus script
        let plutusWitnessSet = TransactionWitnessSet(
            plutusV2Script: .list([plutusV2Script]),
            plutusData: .list([datum]),
            redeemers: .list([redeemer])
        )
        _ = plutusWitnessSet
    }

    @Test func mintingPolicy() throws {
        let keyHash = try PaymentKeyPair.generate().verificationKey.hash()

        // A minting policy that one key signs, before slot 2000
        let mintingPolicy = NativeScript.scriptAll(ScriptAll(scripts: [
            .scriptPubkey(ScriptPubkey(keyHash: keyHash)),
            .invalidHereAfter(AfterScript(slot: 2000)),   // can only mint before slot 2000
        ]))

        let policyId = try mintingPolicy.scriptHash()

        // Mint 1000 MyToken and send them on
        let mintingAsset = Asset([AssetName(from: "MyToken"): 1000])
        let mintingMultiAsset = MultiAsset([policyId: mintingAsset])

        let mintingTxBody = TransactionBody(
            inputs: .list([txInput]),
            outputs: [
                TransactionOutput(
                    address: recipientAddress,
                    amount: Value(coin: 2_000_000, multiAsset: mintingMultiAsset)
                ),
            ],
            fee: 250_000,
            mint: mintingMultiAsset
        )
        _ = mintingTxBody
    }

    @Test func referenceScripts() throws {
        let plutusV2Script = PlutusV2Script(data: Data(hexString: "4e4d01000033222220051200120011")!)
        let scriptAddress = try Address(
            paymentPart: .scriptHash(try plutusScriptHash(script: .plutusV2Script(plutusV2Script))),
            network: .testnet)

        // An output that carries the script, for later transactions to reference
        let scriptOutput = TransactionOutput(
            address: scriptAddress,
            amount: Value(coin: 2_000_000),
            script: .plutusV2Script(plutusV2Script),
            postAlonzo: true
        )

        // A later transaction refers to that output instead of including the script
        let referencingTx = TransactionBody(
            inputs: .list([txInput]),
            outputs: [scriptOutput],
            fee: 200_000,
            referenceInputs: .list([
                TransactionInput(transactionId: scriptRefTxId, index: 0),
            ])
        )
        _ = referencingTx
    }

    @Test func inlineDatums() throws {
        let scriptAddress = recipientAddress
        let datum = PlutusData.bigInt(.int(42))

        // An output that holds its datum inline
        let outputWithDatum = TransactionOutput(
            address: scriptAddress,
            amount: Value(coin: 5_000_000),
            datumOption: DatumOption(datum: datum),
            postAlonzo: true
        )
        _ = try outputWithDatum.toCBORData()
    }
}
