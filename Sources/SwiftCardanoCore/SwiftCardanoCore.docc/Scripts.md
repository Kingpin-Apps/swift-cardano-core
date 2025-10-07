# Scripts

Work with native scripts and smart contracts on Cardano.

## Overview

Scripts in Cardano enable programmable conditions for spending UTxOs and minting assets. SwiftCardanoCore supports both native scripts (simple, built-in logic) and Plutus scripts (full smart contracts) with comprehensive validation and serialization capabilities.

## Key Types & Concepts

### Native Scripts

- ``NativeScript``: Simple scripts with built-in validation logic
- ``ScriptPubkey``: Requires a specific key signature
- ``ScriptAll``: Requires all sub-scripts to be satisfied
- ``ScriptAny``: Requires any one sub-script to be satisfied
- ``ScriptNOfK``: Requires N out of K sub-scripts to be satisfied
- ``ScriptInvalidBefore``: Valid only after a specific slot
- ``ScriptInvalidHereafter``: Valid only before a specific slot

### Plutus Scripts

- ``PlutusV1Script``: First generation Plutus smart contracts
- ``PlutusV2Script``: Enhanced Plutus scripts with improved features
- ``PlutusV3Script``: Latest Plutus script version
- ``PlutusData``: Data passed to Plutus scripts
- ``Redeemer``: Execution parameters for Plutus scripts

### Script Utilities

- ``ScriptHash``: Unique identifier for scripts (used as policy ID)
- ``ScriptType``: Enum containing all script variants
- ``ScriptRef``: Reference to a script in transaction outputs

## Step-by-Step Native Script Creation

### 1. Simple Signature Script

```swift
import SwiftCardanoCore

// Generate keys
let keyPair = try PaymentKeyPair.generate()
let keyHash = try keyPair.verificationKey.hash()

// Create signature script
let sigScript = NativeScript.scriptPubkey(.verificationKeyHash(keyHash))

// Calculate script hash (policy ID)
let scriptHash = try sigScript.scriptHash()
print("Script Hash/Policy ID: \(scriptHash.payload.toHex)")
```

### 2. Multi-Signature Script

```swift
// Generate multiple keys
let keyPair1 = try PaymentKeyPair.generate()
let keyPair2 = try PaymentKeyPair.generate()
let keyPair3 = try PaymentKeyPair.generate()

let keyHash1 = try keyPair1.verificationKey.hash()
let keyHash2 = try keyPair2.verificationKey.hash()
let keyHash3 = try keyPair3.verificationKey.hash()

// Create 2-of-3 multi-sig script
let multiSigScript = NativeScript.scriptNOfK(
    n: 2,
    nativeScripts: [
        .scriptPubkey(.verificationKeyHash(keyHash1)),
        .scriptPubkey(.verificationKeyHash(keyHash2)),
        .scriptPubkey(.verificationKeyHash(keyHash3))
    ]
)
```

### 3. Time-Locked Scripts

```swift
// Script valid only after slot 1000
let afterScript = NativeScript.scriptInvalidBefore(1000)

// Script valid only before slot 2000
let beforeScript = NativeScript.scriptInvalidHereafter(2000)

// Combined time window script (valid between slots 1000-2000)
let timeWindowScript = NativeScript.scriptAll([
    .scriptInvalidBefore(1000),
    .scriptInvalidHereafter(2000)
])
```

### 4. Complex Conditional Scripts

```swift
// Require primary key OR (backup key AND time condition)
let emergencyScript = NativeScript.scriptAny([
    // Primary authentication
    .scriptPubkey(.verificationKeyHash(keyHash1)),
    
    // Emergency recovery after 30 days (assuming ~20s per slot)
    .scriptAll([
        .scriptPubkey(.verificationKeyHash(keyHash2)), // Backup key
        .scriptInvalidBefore(129600) // ~30 days in slots
    ])
])
```

## Plutus Script Integration

### Working with Plutus Scripts

```swift
// Load compiled Plutus script
let scriptBytes = Data(hex: "59015859015501000033332332...")
let plutusV2Script = PlutusV2Script(data: scriptBytes)

// Calculate script hash
let plutusHash = try plutusScriptHash(script: .plutusV2Script(plutusV2Script))

// Create script reference
let scriptRef = try ScriptRef(script: Script(script: .plutusV2Script(plutusV2Script)))
```

### Plutus Data and Redeemers

```swift
// Create Plutus data for script parameters
let datum = try PlutusData.fromJSON("""
{
    "constructor": 0,
    "fields": [
        {"int": 42},
        {"bytes": "deadbeef"}
    ]
}
""")

// Create redeemer for script execution
let redeemer = Redeemer(
    tag: .spend,
    index: 0,
    data: datum,
    exUnits: ExUnits(mem: 1000000, steps: 500000000)
)
```

## Script Usage in Transactions

### Native Script Transactions

```swift
// Create transaction spending from script address
let scriptAddress = try Address(
    paymentPart: .scriptHash(scriptHash),
    network: .testnet
)

// Transaction with script witness
let witnessSet = TransactionWitnessSet<Never>(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([
        // Signatures for keys referenced in script
        VerificationKeyWitness(
            vkey: .verificationKey(VerificationKey(
                payload: keyPair1.verificationKey.payload,
                type: keyPair1.verificationKey.type,
                description: keyPair1.verificationKey.description
            )),
            signature: try keyPair1.signingKey.sign(data: txBody.hash())
        )
    ])),
    nativeScripts: .nonEmptyOrderedSet(NonEmptyOrderedSet([multiSigScript])),
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)
```

### Plutus Script Transactions

```swift
// Transaction with Plutus script
let plutusWitnessSet = TransactionWitnessSet<Never>(
    vkeyWitnesses: nil,
    nativeScripts: nil,
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: .nonEmptyOrderedSet(NonEmptyOrderedSet([plutusV2Script])),
    plutusData: .nonEmptyOrderedSet(NonEmptyOrderedSet([datum])),
    redeemers: .nonEmptyOrderedSet(NonEmptyOrderedSet([redeemer]))
)
```

## Script-Based Asset Minting

### Minting Policy Script

```swift
// Create minting policy with time restriction
let mintingPolicy = NativeScript.scriptAll([
    .scriptPubkey(.verificationKeyHash(keyHash)),
    .scriptInvalidHereafter(2000) // Can only mint before slot 2000
])

let policyId = try mintingPolicy.scriptHash()

// Create minting transaction
let mintingAsset = Asset([AssetName(from: "MyToken"): 1000])
let mintingMultiAsset = MultiAsset([policyId: mintingAsset])

let mintingTxBody = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [
        TransactionOutput(
            address: recipientAddress,
            amount: Value(coin: Coin(2_000_000), multiAsset: mintingMultiAsset)
        )
    ],
    fee: Coin(250_000),
    mint: mintingMultiAsset
)
```

## Advanced Script Features

### Script References (Babbage Era)

```swift
// Include script in transaction output for reference
let scriptOutput = TransactionOutput(
    address: scriptAddress,
    amount: Value(coin: Coin(2_000_000))
)
scriptOutput.scriptRef = scriptRef

// Reference script in later transactions without including full script
let referencingTx = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [scriptOutput],
    fee: Coin(200_000),
    referenceInputs: .nonEmptyOrderedSet(NonEmptyOrderedSet([
        TransactionInput(transactionId: scriptRefTxId, index: 0)
    ]))
)
```

### Inline Datums

```swift
// Create output with inline datum
var outputWithDatum = TransactionOutput(
    address: scriptAddress,
    amount: Value(coin: Coin(5_000_000))
)
outputWithDatum.datum = datum
outputWithDatum.postAlonzo = true // Enable post-Alonzo features
```


## See Also

- <doc:Assets> - Script-based asset minting policies
- <doc:Transactions> - Including scripts in transactions
- <doc:Plutus> - Advanced Plutus script development
- <doc:Addresses> - Script addresses and payment credentials

## Related Symbols

- ``NativeScript``
- ``PlutusV1Script``
- ``PlutusV2Script``
- ``PlutusV3Script``
- ``ScriptHash``
- ``ScriptType``
- ``PlutusData``
- ``Redeemer``
