# Assets

Work with ADA and native tokens on the Cardano blockchain.

## Overview

Cardano supports native assets (tokens) alongside ADA, enabling the creation and transfer of custom tokens without smart contracts. SwiftCardanoCore provides comprehensive support for creating, minting, and managing native assets with full CBOR serialization.

## Key Types & Concepts

### Value Types

- ``Value``: Represents both ADA and native assets in a single structure
- ``Coin``: ADA amounts in lovelace (1 ADA = 1,000,000 lovelace)
- ``MultiAsset``: Collection of native tokens organized by policy
- ``Asset``: Token amounts within a specific policy
- ``AssetName``: Human-readable name for a token (up to 32 bytes)

### Policy and Identification

- ``ScriptHash``: Policy ID that governs asset minting and burning
- ``PolicyId``: Alias for ScriptHash used in asset identification
- Asset fingerprint: Unique identifier combining policy ID and asset name

## Step-by-Step Asset Usage

### 1. Working with ADA (Coin)

```swift
import SwiftCardanoCore

// Create ADA amounts
let oneADA = Coin(1_000_000) // 1 ADA in lovelace
let halfADA = Coin(500_000)  // 0.5 ADA

// Arithmetic operations
let totalADA = oneADA + halfADA
let remainingADA = totalADA - Coin(300_000)

// Create Value with just ADA
let adaValue = Value(coin: oneADA)
```

### 2. Creating Native Assets

```swift
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
```

### 3. Asset Arithmetic

```swift
// Adding values
let value1 = Value(coin: Coin(1_000_000), multiAsset: multiAsset)
let value2 = Value(coin: Coin(500_000))
let combinedValue = value1 + value2

// Subtracting values
let remainingValue = combinedValue - Value(coin: Coin(200_000))

// Check if value contains specific assets
if mixedValue.multiAsset?.contains(policyId: policyId) == true {
    print("Value contains tokens from policy: \(policyId)")
}
```

## Advanced Asset Operations

### Asset Fingerprints

```swift
// Generate asset fingerprint (CIP-14)
extension AssetName {
    func fingerprint(policyId: ScriptHash) -> String {
        let combined = policyId.payload + self.payload
        let hash = // ... Blake2b hash calculation
        return encodeBech32(hrp: "asset", data: hash)
    }
}

// Usage
let fingerprint = tokenName.fingerprint(policyId: policyId)
print("Asset fingerprint: \(fingerprint)")
```

### Asset Metadata (CIP-25)

```swift
// Create NFT metadata following CIP-25
let nftMetadata = Metadata([
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
```

## Minting and Burning

### Minting Transaction

```swift
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
let mintingScript = NativeScript.scriptPubkey(.verificationKeyHash(keyHash))
let witnessSet = TransactionWitnessSet<Never>(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
    nativeScripts: .nonEmptyOrderedSet(NonEmptyOrderedSet([mintingScript])),
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)
```

### Burning Assets

```swift
// Negative amounts indicate burning
let burningAsset = Asset([tokenName: -500]) // Burn 500 tokens
let burningMultiAsset = MultiAsset([policyId: burningAsset])

let burnTxBody = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [txOutput],
    fee: Coin(200_000),
    mint: burningMultiAsset // Negative amounts burn assets
)
```


## See Also

- <doc:Transactions> - Including assets in transactions
- <doc:Scripts> - Minting policies and asset control
- <doc:Metadata> - Asset metadata standards
- <doc:Serialization> - CBOR encoding for assets

## Related Symbols

- ``Value``
- ``Coin``
- ``MultiAsset``
- ``Asset``
- ``AssetName``
- ``ScriptHash``
