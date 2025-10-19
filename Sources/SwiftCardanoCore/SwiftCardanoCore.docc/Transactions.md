# Transactions

Build, sign, and submit Cardano transactions using SwiftCardanoCore.

## Overview

Transactions are the core mechanism for transferring value and executing smart contracts on the Cardano blockchain. SwiftCardanoCore provides comprehensive support for creating, signing, and serializing transactions across all Cardano eras.

## Key Types & Concepts

### Transaction Components

- ``Transaction``: The complete transaction structure containing body, witnesses, and metadata
- ``TransactionBody``: The unsigned transaction containing inputs, outputs, fees, and other transaction data
- ``TransactionInput``: References to unspent transaction outputs (UTxOs)
- ``TransactionOutput``: Destinations for funds with addresses and amounts
- ``TransactionWitnessSet``: Cryptographic proofs validating the transaction

### Value Types

- ``Value``: Represents ADA and native assets
- ``Coin``: ADA amounts in lovelace (1 ADA = 1,000,000 lovelace)
- ``MultiAsset``: Collection of native tokens
- ``Asset``: Individual token amounts within a policy

## Step-by-Step Transaction Building

### 1. Create Transaction Inputs

```swift
import SwiftCardanoCore

// Reference a UTxO to spend
let txId = try TransactionId(from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"))
let txInput = TransactionInput(transactionId: txId, index: 0)
```

### 2. Create Transaction Outputs

```swift
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
```

### 3. Build Transaction Body

```swift
let txBody = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [output, outputWithAssets],
    fee: Coin(200_000), // 0.2 ADA fee
    ttl: 1000000 // Time to live (optional)
)
```

### 4. Sign the Transaction

```swift
// Generate or load signing keys
let paymentKeyPair = try PaymentKeyPair.generate()

// Sign the transaction body hash
let signature = try paymentKeyPair.signingKey.sign(data: txBody.hash())

// Create witness
let witness = VerificationKeyWitness(
    vkey: .verificationKey(VerificationKey(
        payload: paymentKeyPair.verificationKey.payload,
        type: paymentKeyPair.verificationKey.type,
        description: paymentKeyPair.verificationKey.description
    )),
    signature: signature
)

// Create witness set
let witnessSet = TransactionWitnessSet(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
    nativeScripts: nil,
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)
```

### 5. Complete Transaction

```swift
let transaction = Transaction(
    transactionBody: txBody,
    transactionWitnessSet: witnessSet,
    valid: true // Mark as valid
)

// Get transaction ID
let transactionId = transaction.id
print("Transaction ID: \(transactionId?.payload.toHex ?? "unknown")")
```

## Advanced Transaction Features

### Multi-Signature Transactions

```swift
// Create multiple witnesses for multi-sig
let keyPair1 = try PaymentKeyPair.generate()
let keyPair2 = try PaymentKeyPair.generate()

let signature1 = try keyPair1.signingKey.sign(data: txBody.hash())
let signature2 = try keyPair2.signingKey.sign(data: txBody.hash())

let witness1 = VerificationKeyWitness(
    vkey: .verificationKey(VerificationKey(
        payload: keyPair1.verificationKey.payload,
        type: keyPair1.verificationKey.type,
        description: keyPair1.verificationKey.description
    )),
    signature: signature1
)

let witness2 = VerificationKeyWitness(
    vkey: .verificationKey(VerificationKey(
        payload: keyPair2.verificationKey.payload,
        type: keyPair2.verificationKey.type,
        description: keyPair2.verificationKey.description
    )),
    signature: signature2
)

let multiSigWitnessSet = TransactionWitnessSet(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness1, witness2])),
    nativeScripts: nil,
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)
```

### Script Transactions

```swift
// Add native script to witness set
let keyHash = try paymentKeyPair.verificationKey.hash()
let nativeScript = NativeScript.scriptPubkey(.verificationKeyHash(keyHash))

let scriptWitnessSet = TransactionWitnessSet(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
    nativeScripts: .nonEmptyOrderedSet(NonEmptyOrderedSet([nativeScript])),
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)
```

### Minting Transactions

```swift
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
```

## CBOR Serialization

### Serialize Transaction

```swift
// Convert to CBOR bytes
let cborData = try transaction.toCBORData()

// Convert to CBOR hex string
let cborHex = try transaction.toCBORHex()
print("CBOR: \(cborHex)")
```

### Deserialize Transaction

```swift
// From CBOR data
let restoredTransaction = try Transaction.fromCBOR(data: cborData)

// From CBOR hex string
let transactionFromHex = try Transaction.fromCBOR(hex: cborHex)
```

## Transaction File Operations

### Save and Load Methods

Transactions conform to the ``PayloadJSONSerializable`` protocol, providing convenient methods for saving to and loading from JSON files in Cardano CLI-compatible format.

```swift
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
assert(transaction.id == loadedTransaction.id)
```

### File Format Compatibility

The save and load methods are fully compatible with Cardano CLI transaction files:

```swift
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
```

### Working with Transaction Files

```swift
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
```


## See Also

- <doc:Assets> - Working with native assets and tokens
- <doc:Scripts> - Native scripts and smart contracts  
- <doc:Certificates> - Stake registration and delegation
- <doc:Metadata> - Transaction metadata and auxiliary data
- <doc:Serialization> - CBOR encoding and decoding

## Related Symbols

- ``Transaction``
- ``TransactionBody``
- ``TransactionInput``
- ``TransactionOutput``
- ``TransactionWitnessSet``
- ``Value``
- ``Coin``
- ``MultiAsset``
