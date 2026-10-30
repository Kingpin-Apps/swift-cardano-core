import Foundation
import SwiftNaCl
import Testing
import SwiftCardanoCore

/// The code examples of the Assets guide (`Assets.md`), compiled and run so
/// that the guide stays true to the API. Each test holds one example as the
/// guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Assets guide examples")
struct AssetsGuideExamplesTests {
    /// Stand-ins for values the guide assumes the reader already has.
    let policyId = try! ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc"))
    let tokenName = AssetName(from: "MyToken")
    let multiAsset = MultiAsset([
        try! ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc")):
            Asset([AssetName(from: "MyToken"): 1000]),
    ])
    let txInput = TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)
    let recipientAddress = try! Address(
        paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 3, count: 28))),
        network: .testnet)
    let keyPair = try! PaymentKeyPair.generate()
    var keyHash: VerificationKeyHash { try! keyPair.verificationKey.hash() }
    var witness: VerificationKeyWitness {
        VerificationKeyWitness(
            vkey: .verificationKey(keyPair.verificationKey),
            signature: try! keyPair.signingKey.sign(data: Data(repeating: 0, count: 32)))
    }
    var txOutput: TransactionOutput {
        TransactionOutput(address: recipientAddress, amount: Value(coin: 2_000_000))
    }

    /// A Blake2b-160 hash, as a reader would take from a crypto library.
    static func blake2b160(_ data: Data) throws -> Data {
        try SwiftNaCl.Hash().blake2b(data: data, digestSize: 20, encoder: RawEncoder.self)
    }

    @Test func workingWithADA() throws {
        // Create ADA amounts
        let oneADA = Coin(1_000_000) // 1 ADA in lovelace
        let halfADA = Coin(500_000)  // 0.5 ADA

        // Arithmetic operations
        let totalADA = oneADA + halfADA
        let remainingADA = totalADA - Coin(300_000)

        // Create Value with just ADA
        let adaValue = Value(coin: oneADA)
        #expect(remainingADA == 1_200_000)
        #expect(adaValue.coin == 1_000_000)
    }

    @Test func creatingNativeAssets() throws {
        // Define policy ID (typically derived from minting script)
        let policyId = try ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc"))

        // Create asset names
        let tokenName = AssetName(from: "MyToken")
        let nftName = AssetName(from: "MyNFT001")

        // Create asset with quantities
        let asset = Asset([
            tokenName: 1000,    // 1000 tokens
            nftName: 1          // 1 NFT
        ])

        // Create multi-asset structure
        let multiAsset = MultiAsset([policyId: asset])

        // Create Value with ADA and native assets
        let mixedValue = Value(coin: Coin(2_000_000), multiAsset: multiAsset)
        #expect(mixedValue.multiAsset.data[policyId]?.data[nftName] == 1)
    }

    @Test func assetArithmetic() throws {
        let mixedValue = Value(coin: Coin(2_000_000), multiAsset: multiAsset)

        // Adding values
        let value1 = Value(coin: Coin(1_000_000), multiAsset: multiAsset)
        let value2 = Value(coin: Coin(500_000))
        let combinedValue = value1 + value2

        // Subtracting values
        let remainingValue = combinedValue - Value(coin: Coin(200_000))

        // Check if value contains specific assets
        if mixedValue.multiAsset.data[policyId] != nil {
            print("Value contains tokens from policy: \(policyId)")
        }
        #expect(remainingValue.coin == 1_300_000)
    }

    @Test func assetFingerprints() throws {
        let blake2b160 = Self.blake2b160

        // CIP-14: the Bech32 ("asset") encoding of the Blake2b-160 hash
        // of the policy ID followed by the asset name
        func fingerprint(policyId: ScriptHash, assetName: AssetName) throws -> String? {
            let hash = try blake2b160(policyId.payload + assetName.payload)
            return Bech32().encode(hrp: "asset", witprog: hash)
        }

        // Usage
        let tokenFingerprint = try fingerprint(policyId: policyId, assetName: tokenName)
        print("Asset fingerprint: \(tokenFingerprint ?? "")")

        // A CIP-14 test vector
        let cip14Policy = try ScriptHash(from: .string("7eae28af2208be856f7a119668ae52a49b73725e326dc16579dcc373"))
        #expect(try fingerprint(policyId: cip14Policy, assetName: try AssetName(payload: Data()))
            == "asset1rjklcrnsdzqp65wjgrg55sy9723kw09mlgvlc3")
    }

    @Test func assetMetadata() throws {
        // Create NFT metadata following CIP-25
        let nftMetadata = try Metadata([
            721: .map([
                .text(policyId.payload.toHex): .map([
                    .text("MyNFT001"): .map([
                        .text("name"): .text("My First NFT"),
                        .text("description"): .text("This is my first NFT on Cardano"),
                        .text("image"): .text("ipfs://QmYourImageHash"),
                        .text("mediaType"): .text("image/png"),
                        .text("attributes"): .list([
                            .map([
                                .text("trait_type"): .text("Rarity"),
                                .text("value"): .text("Legendary")
                            ])
                        ])
                    ])
                ])
            ])
        ])
        _ = try nftMetadata.toCBORData()
    }

    @Test func mintingTransaction() throws {
        // Assets to mint
        let mintAmount: Int64 = 1000
        let mintingAsset = Asset([tokenName: mintAmount])
        let mintingMultiAsset = MultiAsset([policyId: mintingAsset])

        // Create transaction body with minting
        let txBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([txInput])),
            outputs: [
                TransactionOutput(
                    address: recipientAddress,
                    amount: Value(coin: Coin(2_000_000), multiAsset: mintingMultiAsset)
                )
            ],
            fee: Coin(250_000),
            mint: mintingMultiAsset // Assets to mint
        )

        // Add minting policy script to witnesses
        let mintingScript = NativeScript.scriptPubkey(ScriptPubkey(keyHash: keyHash))
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
            nativeScripts: .nonEmptyOrderedSet(NonEmptyOrderedSet([mintingScript]))
        )
        _ = try Transaction(transactionBody: txBody, transactionWitnessSet: witnessSet).toCBORData()
    }

    @Test func burningAssets() throws {
        // Negative amounts indicate burning
        let burningAsset = Asset([tokenName: -500]) // Burn 500 tokens
        let burningMultiAsset = MultiAsset([policyId: burningAsset])

        let burnTxBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([txInput])),
            outputs: [txOutput],
            fee: Coin(200_000),
            mint: burningMultiAsset // Negative amounts burn assets
        )
        _ = try burnTxBody.toCBORData()
    }
}
