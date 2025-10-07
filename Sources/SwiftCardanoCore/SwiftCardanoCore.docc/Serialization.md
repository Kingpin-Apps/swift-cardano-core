# Serialization

CBOR and JSON encoding/decoding for Cardano data structures.

## Overview

SwiftCardanoCore uses CBOR (Concise Binary Object Representation) as the primary serialization format for all Cardano data structures. This ensures compatibility with the Cardano blockchain and other ecosystem tools. The library also provides JSON support for human-readable formats and debugging.

## Key Types & Concepts

### Serialization Protocols

- ``CBORSerializable``: Protocol for types that can be encoded/decoded to/from CBOR
- ``Primitive``: Intermediate representation for CBOR data
- ``AnyValue``: Generic value wrapper for dynamic CBOR content

### CBOR Features

- Deterministic encoding for consistent transaction hashes
- Support for all CBOR major types and tags
- Efficient binary representation
- Round-trip serialization guarantee

## Step-by-Step Serialization

### 1. Basic CBOR Operations

```swift
import SwiftCardanoCore

// Serialize to CBOR data
let address = try Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
let cborData = try address.toCBORData()
let cborHex = try address.toCBORHex()

print("CBOR bytes: \(cborData.toHex)")
print("CBOR hex: \(cborHex)")

// Deserialize from CBOR
let restoredAddress = try Address.fromCBOR(data: cborData)
let addressFromHex = try Address.fromCBOR(hex: cborHex)
```

### 2. Transaction Serialization

```swift
// Create and serialize a complete transaction
let transaction = Transaction(
    transactionBody: txBody,
    transactionWitnessSet: witnessSet,
    valid: true
)

// Serialize for submission
let txCBOR = try transaction.toCBORData()
let txHex = try transaction.toCBORHex()

// Calculate transaction hash
let txHash = transaction.id
print("Transaction Hash: \(txHash?.payload.toHex ?? "unknown")")
```

### 3. Deterministic Encoding

```swift
// Ensure deterministic encoding for reproducible hashes
let deterministicCBOR = try transaction.toCBORData(deterministic: true)
let deterministicHex = try transaction.toCBORHex(deterministic: true)

// This will always produce the same bytes for the same transaction
assert(deterministicCBOR == try transaction.toCBORData(deterministic: true))
```

## Advanced Serialization

### Custom CBOR Encoding

```swift
// Implement CBORSerializable for custom types
struct CustomData: CBORSerializable {
    let value: Int
    let text: String
    
    init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .int(intValue) = elements[0],
              case let .string(stringValue) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid CustomData format")
        }
        
        self.value = intValue
        self.text = stringValue
    }
    
    func toPrimitive() throws -> Primitive {
        return .list([
            .int(value),
            .string(text)
        ])
    }
}

// Usage
let customData = CustomData(value: 42, text: "Hello")
let serialized = try customData.toCBORData()
let deserialized = try CustomData.fromCBOR(data: serialized)
```

### Working with AnyValue

```swift
// Create dynamic CBOR content
let dynamicValue = AnyValue.map([
    "name": .string("Alice"),
    "age": .int(30),
    "tokens": .array([
        .string("TokenA"),
        .string("TokenB")
    ])
])

let dynamicCBOR = try dynamicValue.toCBORData()
let restored = try AnyValue.fromCBOR(data: dynamicCBOR)
```

## JSON Serialization

### Transaction Metadata JSON

```swift
// Create metadata with JSON-compatible structure
let metadata = Metadata([
    1: .text("Hello Cardano!"),
    2: .map([
        .text("name"): .text("My NFT"),
        .text("description"): .text("A beautiful NFT"),
        .text("image"): .text("ipfs://QmHash...")
    ]),
    3: .list([
        .int(1),
        .int(2),
        .int(3)
    ])
])

// Convert to JSON for external APIs
let jsonString = try metadata.toJSON()
print("Metadata JSON: \(jsonString)")

// Parse from JSON
let parsedMetadata = try Metadata.fromJSON(jsonString)
```

### PlutusData JSON

```swift
// Convert PlutusData to/from JSON (CIP-114 format)
let plutusData = try MyPlutusData(
    field1: 42,
    field2: Data("hello".utf8),
    field3: [1, 2, 3]
)

let plutusJSON = try plutusData.toJSON()
let fromJSON = try MyPlutusData.fromJSON(plutusJSON)
```

## File Operations

### PayloadJSONSerializable Protocol

Many Cardano types implement the ``PayloadJSONSerializable`` protocol, providing convenient file I/O operations for saving and loading data in JSON format compatible with Cardano CLI tools.

```swift
// Save transaction to file
let transaction = Transaction(
    transactionBody: txBody,
    transactionWitnessSet: witnessSet,
    valid: true
)

// Save to JSON file (Cardano CLI compatible)
try transaction.save(to: "my-transaction.tx")
print("Transaction saved successfully")

// Load transaction from file
let loadedTransaction = try Transaction<Never>.load(from: "my-transaction.tx")
print("Transaction loaded: \(loadedTransaction.id?.payload.toHex ?? "unknown")")

// Verify integrity
assert(transaction.id == loadedTransaction.id)
```

### Address File Operations

```swift
// Save different address types
let paymentAddr = try Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
let stakeAddr = try Address.fromBech32("stake_test1ur2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqtxwdg")
let scriptAddr = try Address.fromBech32("addr_test1wpnnm9z6mjhqyqk3s4w4x7mgh90clkqm6q5s5s5s5s5s5s5qqqqqqq")

// Save addresses to files
try paymentAddr.save(to: "payment.addr")
try stakeAddr.save(to: "stake.addr")
try scriptAddr.save(to: "script.addr")

// Load addresses from files
let loadedPayment = try Address.load(from: "payment.addr")
let loadedStake = try Address.load(from: "stake.addr")
let loadedScript = try Address.load(from: "script.addr")

// Verify addresses match
assert(paymentAddr.toBech32() == loadedPayment.toBech32())
```

### Key File Operations

```swift
// Save cryptographic keys
let privateKey = try Ed25519PrivateKey.generateNew()
let publicKey = privateKey.publicKey

// Save keys to files (JSON format)
try privateKey.save(to: "payment.skey")
try publicKey.save(to: "payment.vkey")

// Load keys from files
let loadedPrivateKey = try Ed25519PrivateKey.load(from: "payment.skey")
let loadedPublicKey = try Ed25519PublicKey.load(from: "payment.vkey")

// Verify key pairs match
assert(loadedPrivateKey.publicKey.rawData == loadedPublicKey.rawData)
```

### Metadata File Operations

```swift
// Create rich metadata
let nftMetadata = Metadata([
    721: .map([
        .text("policy_id"): .text("b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8"),
        .text("asset_name"): .map([
            .text("name"): .text("My Amazing NFT"),
            .text("description"): .text("A unique digital collectible"),
            .text("image"): .text("ipfs://QmHash123..."),
            .text("attributes"): .list([
                .map([
                    .text("trait_type"): .text("Rarity"),
                    .text("value"): .text("Epic")
                ]),
                .map([
                    .text("trait_type"): .text("Color"),
                    .text("value"): .text("Blue")
                ])
            ])
        ])
    ])
])

// Save metadata to file
try nftMetadata.save(to: "nft-metadata.json")

// Load and verify metadata
let loadedMetadata = try Metadata.load(from: "nft-metadata.json")
let originalJSON = try nftMetadata.toJSON()
let loadedJSON = try loadedMetadata.toJSON()

// JSON should be identical
assert(originalJSON == loadedJSON)
```

### Certificate File Operations

```swift
// Create stake pool registration certificate
let poolParams = PoolParams(
    operator: poolKeyHash,
    vrfKeyHash: vrfKeyHash,
    pledge: Coin(1000000000), // 1000 ADA
    cost: Coin(340000000),    // 340 ADA
    margin: UnitInterval(numerator: 1, denominator: 20), // 5%
    rewardAccount: rewardAddress,
    poolOwners: [ownerKeyHash],
    relays: [relay],
    poolMetadata: poolMetadataHash
)

let poolRegistration = PoolRegistrationCertificate(poolParams: poolParams)

// Save certificate to file
try poolRegistration.save(to: "pool-registration.cert")

// Load certificate from file
let loadedCert = try PoolRegistrationCertificate.load(from: "pool-registration.cert")
```


## See Also

- <doc:Transactions> - Transaction serialization examples
- <doc:Metadata> - Metadata JSON encoding
- <doc:Plutus> - PlutusData serialization
- <doc:Assets> - Value and asset encoding

## Related Symbols

- ``CBORSerializable``
- ``Primitive``
- ``AnyValue``
- ``Metadata``
- ``PlutusData``
