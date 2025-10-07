![GitHub Workflow Status](https://github.com/Kingpin-Apps/swift-cardano-core/actions/workflows/swift.yml/badge.svg)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKingpin-Apps%2Fswift-cardano-core%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Kingpin-Apps/swift-cardano-core)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKingpin-Apps%2Fswift-cardano-core%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Kingpin-Apps/swift-cardano-core)

# SwiftCardanoCore - Swift implementation of Cardano Data Types

SwiftCardanoCore is a Swift implementation of Cardano Data Types with CBOR (and JSON) serialization.

## Installation

### Swift Package Manager

To add SwiftCardanoCore as dependency to your Xcode project:

1. In Xcode, select `File` > `Add Package Dependencies`
2. Enter the repository URL: `https://github.com/Kingpin-Apps/swift-cardano-core.git`
3. Click `Add Package` and import `SwiftCardanoCore`

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "1.0.0")
]
```

## Data Types
- [x] Addresses
- [x] Certificate
- [x] Config Files
- [x] Governance
- [x] Keys
- [x] Metadata
- [x] Native Scripts
- [x] Parameters
- [x] Plutus
- [x] Stake Pools
- [x] Transactions
- [x] Credentials
- [x] Hashing
- [x] Network
- [x] Signatures
- [x] And more...


## Usage

### Key Management

#### Generating Keys

```swift
import SwiftCardanoCore

// Generate individual keys
let paymentSKey = try PaymentSigningKey.generate()
let paymentVKey = try PaymentVerificationKey.fromSigningKey(paymentSKey)

let stakeSKey = try StakeSigningKey.generate()
let stakeVKey = try StakeVerificationKey.fromSigningKey(stakeSKey)

// Or use KeyPair convenience classes
let paymentKeyPair = try PaymentKeyPair.generate()
let stakeKeyPair = try StakeKeyPair.generate()
```

#### Saving and Loading Keys

```swift
// Save keys to files
try paymentKeyPair.signingKey.save(to: "payment.skey")
try paymentKeyPair.verificationKey.save(to: "payment.vkey")
try stakeKeyPair.signingKey.save(to: "stake.skey")
try stakeKeyPair.verificationKey.save(to: "stake.vkey")

// Load keys from files
let loadedPaymentSKey = try PaymentSigningKey.load(from: "payment.skey")
let loadedStakeVKey = try StakeVerificationKey.load(from: "stake.vkey")
```

### Address Creation

#### Base Addresses (Payment + Stake)

```swift
// Create a base address from keys
let address = try Address(
    paymentPart: .verificationKeyHash(try paymentVKey.hash()),
    stakePart: .verificationKeyHash(try stakeVKey.hash()),
    network: .testnet
)

// Save address to file
try address.save(to: "base.addr")

// Parse address from string
let parsedAddress = try Address(from: "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
```

#### Enterprise Addresses (Payment Only)

```swift
let enterpriseAddress = try Address(
    paymentPart: .verificationKeyHash(try paymentVKey.hash()),
    network: .mainnet
)
```

#### Stake Addresses

```swift
let stakeAddress = try Address(
    stakingPart: .verificationKeyHash(try stakeVKey.hash()),
    network: .testnet
)
```

### Transaction Building

#### Basic Transaction

```swift
// Create transaction inputs
let txId = try TransactionId(from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"))
let txInput = TransactionInput(transactionId: txId, index: 0)

// Create transaction outputs
let recipientAddress = try Address(from: "addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x")
let amount = Value(coin: 1_000_000) // 1 ADA
let txOutput = TransactionOutput(address: recipientAddress, amount: amount)

// Create transaction body
let txBody = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [txOutput],
    fee: Coin(200_000) // 0.2 ADA
)

// Create witness
let signature = try paymentSKey.sign(data: txBody.hash())
let witness = VerificationKeyWitness(
    vkey: .verificationKey(VerificationKey(
        payload: paymentVKey.payload,
        type: paymentVKey.type,
        description: paymentVKey.description
    )),
    signature: signature
)

// Create complete transaction
let witnessSet = TransactionWitnessSet<Never>(
    vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet([witness])),
    nativeScripts: nil,
    bootstrapWitness: nil,
    plutusV1Script: nil,
    plutusV2Script: nil,
    plutusData: nil,
    redeemers: nil
)

let transaction = Transaction(
    transactionBody: txBody,
    transactionWitnessSet: witnessSet
)
```

### Working with Native Assets

```swift
// Create multi-asset value
let policyId = try ScriptHash(from: .string("d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc"))
let assetName = AssetName(from: "MyToken")

let asset = Asset([assetName: 1000])
let multiAsset = MultiAsset([policyId: asset])
let valueWithAssets = Value(coin: 2_000_000, multiAsset: multiAsset)

let outputWithAssets = TransactionOutput(address: recipientAddress, amount: valueWithAssets)
```

### Scripts

#### Native Scripts

```swift
// Signature script
let keyHash = try paymentVKey.hash()
let sigScript = NativeScript.scriptPubkey(.verificationKeyHash(keyHash))

// Time lock script (valid after slot 1000)
let timeLockScript = NativeScript.scriptInvalidBefore(1000)

// Multi-signature script (2 of 3)
let keyHash1 = try paymentVKey.hash()
let keyHash2 = try stakeVKey.hash()
let keyHash3 = try PaymentVerificationKey.generate().hash()

let multiSigScript = NativeScript.scriptNOfK(
    n: 2,
    nativeScripts: [
        .scriptPubkey(.verificationKeyHash(keyHash1)),
        .scriptPubkey(.verificationKeyHash(keyHash2)),
        .scriptPubkey(.verificationKeyHash(keyHash3))
    ]
)
```

#### Plutus Scripts

```swift
// Load Plutus script from compiled code
let scriptData = Data(hex: "590a4d590a4a01000032323232323232323232...")
let plutusV2Script = PlutusV2Script(data: scriptData)

// Calculate script hash
let scriptHash = try plutusScriptHash(script: .plutusV2Script(plutusV2Script))
```

### CBOR Serialization

```swift
// Serialize to CBOR
let cborData = try transaction.toCBORData()
let cborHex = try transaction.toCBORHex()

// Deserialize from CBOR
let restoredTransaction = try Transaction<Never>.fromCBOR(data: cborData)
let transactionFromHex = try Transaction<Never>.fromCBOR(hex: cborHex)
```

### Certificates

#### Stake Registration

```swift
let stakeCredential = Credential.verificationKeyHash(try stakeVKey.hash())
let stakeRegistration = StakeRegistrationCertificate(
    stakeCredential: stakeCredential,
    coin: Coin(2_000_000) // Deposit
)
let regCert = Certificate.stakeRegistration(stakeRegistration)
```

#### Stake Delegation

```swift
let poolKeyHash = try PoolKeyHash(from: .string("pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy"))
let delegation = StakeDelegationCertificate(
    stakeCredential: stakeCredential,
    poolKeyHash: poolKeyHash
)
let delegCert = Certificate.stakeDelegation(delegation)
```

### Metadata and Auxiliary Data

```swift
// Create transaction metadata
let metadata = Metadata([
    1: .text("Hello Cardano!"),
    2: .int(42),
    3: .list([.text("item1"), .text("item2")]),
    4: .map([
        .text("key1"): .text("value1"),
        .text("key2"): .int(123)
    ])
])

// Create auxiliary data with metadata
let auxiliaryData = try AuxiliaryData(data: .metadata(metadata))

// Include in transaction
let transactionWithMetadata = Transaction(
    transactionBody: txBody,
    transactionWitnessSet: witnessSet,
    valid: true,
    auxiliaryData: auxiliaryData
)
```

### Advanced Examples

#### Working with UTxOs

```swift
// Query UTxOs (pseudo-code - actual implementation depends on your data source)
struct UTxO {
    let txHash: String
    let outputIndex: Int
    let address: Address
    let value: Value
}

// Select UTxOs for transaction
func selectUTxOs(utxos: [UTxO], targetAmount: Coin) -> [UTxO] {
    var selected: [UTxO] = []
    var total = Coin(0)
    
    for utxo in utxos {
        selected.append(utxo)
        total = total + utxo.value.coin
        if total >= targetAmount {
            break
        }
    }
    
    return selected
}
```

#### Minting Native Assets

```swift
// Create minting transaction
let mintAmount: Int64 = 1000
let mintAsset = Asset([assetName: mintAmount])
let mintValue = MultiAsset([policyId: mintAsset])

// Add minting to transaction body
let txBodyWithMint = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [txOutput],
    fee: Coin(200_000),
    mint: mintValue
)
```

### Error Handling

```swift
do {
    let address = try Address(from: "invalid_address_string")
} catch CardanoCoreError.invalidArgument(let message) {
    print("Invalid address: \(message)")
} catch CardanoCoreError.deserializeError(let message) {
    print("Deserialization failed: \(message)")
} catch CardanoCoreError.encodingError(let message) {
    print("Encoding failed: \(message)")
} catch CardanoCoreError.typeError(let message) {
    print("Type error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Testing

SwiftCardanoCore includes comprehensive test coverage. To run tests:

```bash
swift test
```

### Compatibility

- **Cardano Node**: Compatible with latest Cardano node versions
- **Era Support**: Byron, Shelley, Allegra, Mary, Alonzo, Babbage, Conway
- **Swift Version**: Requires Swift 5.7 or later
- **Platforms**: macOS 12.0+, iOS 15.0+, tvOS 15.0+, watchOS 8.0+

### Contributing

Contributions are welcome! Please see our contributing guidelines and submit pull requests to the repository.

### License

This project is licensed under the Apache 2.0 License - see the LICENSE file for details.


## Data Types
- [x] Addresses
- [x] Certificate
- [x] Config Files
- [x] Governance
- [x] Keys
- [x] Metadata
- [x] Native Scripts
- [x] Parameters
- [x] Plutus
- [x] Stake Pools
- [x] Transactions
- [x] Credentials
- [x] Hashing
- [x] Network
- [x] Signatures
- [x] And more...
