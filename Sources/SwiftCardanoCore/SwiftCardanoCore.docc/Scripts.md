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
- ``ScriptNofK``: Requires N out of K sub-scripts to be satisfied
- ``BeforeScript``: `invalid_before` — valid only from a slot on (cardano-cli type `"after"`)
- ``AfterScript``: `invalid_hereafter` — valid only before a slot (cardano-cli type `"before"`)

The two time locks are named for the ledger field they set, which reads the
opposite way round to cardano-cli's JSON names.

A native script read from CBOR — on its own, or from a transaction's witness
set, auxiliary data or a reference script — is read as the ledger reads it:
records and lists of definite or indefinite length, integers of any width, and
any depth. It keeps the bytes it was read from, and its hash and encoding are
taken over them, so `scriptHash()` matches the ledger's however the script was
written. A script built in Swift is written in its canonical form.

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

These examples are compiled and run by the package's tests
(`ScriptsGuideExamplesTests`), so they stay true to the API.

### 1. Simple Signature Script

```swift
import SwiftCardanoCore

// Generate keys
let keyPair = try PaymentKeyPair.generate()
let keyHash = try keyPair.verificationKey.hash()

// Create signature script
let sigScript = NativeScript.scriptPubkey(ScriptPubkey(keyHash: keyHash))

// Calculate script hash (policy ID)
let scriptHash = try sigScript.scriptHash()
print("Script Hash/Policy ID: \(scriptHash.payload.toHex)")
```

### 2. Multi-Signature Script

```swift
// Generate multiple keys
let keyPair1 = try PaymentKeyPair.generate()
let keyHash1 = try keyPair1.verificationKey.hash()
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
```

### 3. Time-Locked Scripts

```swift
// Valid from slot 1000 on (invalid_before; cardano-cli type "after")
let afterSlot = NativeScript.invalidBefore(BeforeScript(slot: 1000))

// Valid only before slot 2000 (invalid_hereafter; cardano-cli type "before")
let beforeSlot = NativeScript.invalidHereAfter(AfterScript(slot: 2000))

// Valid from slot 1000 up to slot 2000
let timeWindowScript = NativeScript.scriptAll(ScriptAll(scripts: [afterSlot, beforeSlot]))
```

### 4. Complex Conditional Scripts

```swift
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
```

## Plutus Script Integration

### Working with Plutus Scripts

```swift
// Load a compiled Plutus script: its flat-encoded bytes
let scriptBytes = Data(hexString: "4e4d01000033222220051200120011")!
let plutusV2Script = PlutusV2Script(data: scriptBytes)

// Calculate the script hash
let plutusHash = try plutusScriptHash(script: .plutusV2Script(plutusV2Script))

// Create a script reference
let scriptRef = try ScriptRef(script: Script(script: .plutusV2Script(plutusV2Script)))
```

### Plutus Data and Redeemers

```swift
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
assert(datum == built)

// A redeemer for spending the first input
let redeemer = Redeemer(
    tag: .spend,
    index: 0,
    data: datum,
    exUnits: ExecutionUnits(mem: 1_000_000, steps: 500_000_000)
)
```

#### Two values are equal when they describe the same data

``PlutusData`` carries representation detail that has no meaning on chain: a byte
string is held as `.boundedBytes` or `.byteString` depending on its length and
remembers the chunks it was read in, an integer as `.int`, `.bigUInt` or `.bigNInt`
depending on its magnitude, a list as `.array` or `.indefiniteArray` and a map as
`.map` or `.indefiniteMap` depending on how they were written, and a ``Constr``
remembers whether its fields were written with an indefinite-length array and
whether it was written in the general `#6.102` form. A map's pairs, their order
and any repeated key are part of its value, so `==` compares those.

`==` ignores all of it and compares structure and content, which is what the
ledger compares. It has to: a datum read off the chain and the same value rebuilt
in Swift routinely take different representations, so comparing that detail would
make two values with byte-identical CBOR come out unequal.

```swift
let raw = Data(repeating: 7, count: 8)
let fromChain = PlutusData.bytes(.byteString(ByteString(bytes: raw)))
let rebuilt   = PlutusData.bytes(.boundedBytes(try BoundedBytes(bytes: raw)))

assert(fromChain == rebuilt)                                  // the same bytes
assert(try fromChain.toCBORHex() == rebuilt.toCBORHex())       // and the same CBOR
```

Encoding follows the same rule from the other side, so equal values always produce
equal bytes — and therefore the same datum hash. An integer goes on the wire in the
smallest form that holds it, and as a CBOR bignum only when it does not fit in 64
bits, whichever case it happens to be held in.

A map, though, keeps its order: a Plutus map is an ordered list of pairs rather
than a dictionary, so `{1: a, 2: b}` and `{2: b, 1: a}` are different values with
different hashes. A map holds its pairs as ``MapPairs``, which keeps them in order
— repeated keys included — so build one from a sequence of pairs:

```swift
let a = PlutusData.bytes(try Bytes(from: Data("a".utf8)))
let b = PlutusData.bytes(try Bytes(from: Data("b".utf8)))
let one = PlutusData.bigInt(.int(1)), two = PlutusData.bigInt(.int(2))

let first  = PlutusData.map(MapPairs([(one, a), (two, b)]))
let second = PlutusData.map(MapPairs([(two, b), (one, a)]))

assert(first != second)
assert(try first.hash() != second.hash())
```

## Script Usage in Transactions

The transaction examples assume a `txBody`, a `txInput`, a `recipientAddress`
and a `scriptRefTxId` of your own.

### Native Script Transactions

```swift
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
```

### Plutus Script Transactions

```swift
// The witness set of a transaction that runs a Plutus script
let plutusWitnessSet = TransactionWitnessSet(
    plutusV2Script: .list([plutusV2Script]),
    plutusData: .list([datum]),
    redeemers: .list([redeemer])
)
```

## Script-Based Asset Minting

### Minting Policy Script

```swift
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
```

## Advanced Script Features

### Script References (Babbage Era)

```swift
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
```

### Inline Datums

```swift
// An output that holds its datum inline
let outputWithDatum = TransactionOutput(
    address: scriptAddress,
    amount: Value(coin: 5_000_000),
    datumOption: DatumOption(datum: datum),
    postAlonzo: true
)
```


## See Also

- <doc:Assets> - Script-based asset minting policies
- <doc:Transactions> - Including scripts in transactions
- <doc:Plutus> - Advanced Plutus script development
- <doc:Addresses> - Script addresses and payment credentials

## Cost models and the script integrity hash

``CostModels`` encodes to the ledger's **language views** form — the one
`script_data_hash` is taken over — not the shape cost models have inside protocol
parameters:

- **PlutusV2 and V3** use an unsigned-integer key and a definite-length array of
  costs.
- **PlutusV1** keeps a legacy shape from the ledger's own history: a byte-string key
  holding the language id, and a byte string holding the serialised cost model.
- Keys are emitted in canonical order, so the integer keys precede the longer V1 key.

A cost model may be any length. The built-in parameter-name templates describe the
protocol version they were written for, and every Plutus release adds parameters, so
a model longer than its template keeps all of its values in order rather than being
rejected — which is what a current node sends.

## Related Symbols

- ``NativeScript``
- ``ScriptPubkey``
- ``ScriptAll``
- ``ScriptAny``
- ``ScriptNofK``
- ``BeforeScript``
- ``AfterScript``
- ``PlutusV1Script``
- ``PlutusV2Script``
- ``PlutusV3Script``
- ``ScriptHash``
- ``ScriptType``
- ``PlutusData``
- ``Redeemer``
