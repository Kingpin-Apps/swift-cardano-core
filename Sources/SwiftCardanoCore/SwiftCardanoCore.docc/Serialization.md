# Serialization

CBOR and JSON encoding/decoding for Cardano data structures.

## Overview

SwiftCardanoCore uses CBOR (Concise Binary Object Representation) as the primary serialization format for all Cardano data structures. This ensures compatibility with the Cardano blockchain and other ecosystem tools. The library also provides JSON support for human-readable formats and debugging.

## Key Types & Concepts

### Serialization Protocols

- ``CBORSerializable``: Protocol for types that can be encoded/decoded to/from CBOR
- ``Primitive``: Intermediate representation for CBOR data, and a value for dynamic CBOR content
- ``AnyValue``: CBORCodable's generic value, which ``Primitive/toAnyValue()`` converts to
- ``PlutusDataProtocol``: Protocol for types of your own that are Plutus data

### CBOR Features

- Deterministic encoding for consistent transaction hashes
- Support for all CBOR major types and tags
- Efficient binary representation
- Round-trip serialization guarantee

## Step-by-Step Serialization

These examples are compiled and run by the package's tests
(`SerializationGuideExamplesTests`), so they stay true to the API; the ones
that write files are compiled but not run. They assume a `txBody` and a
`witnessSet` of your own, and the hex of a transaction, `hex`.

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
let addressFromHex = try Address.fromCBORHex(cborHex)
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

### 3. Encoding is deterministic, and faithful

Encoding the same value twice always produces the same bytes, in the same process
and across processes. More than that: a transaction decoded from CBOR re-encodes to
the bytes it came from.

Both matter because a transaction body is hashed, and that hash is its id and what
a witness signs. An encoding that varies between runs produces a signature the
ledger rejects; an encoding that differs from the original gives the wrong
transaction id and invalidates every signature already on it.

```swift
let original = try Transaction.fromCBORHex(hex)

// The same bytes back, including in another process.
assert(try original.toCBORHex() == hex)
```

Four things make this hold:

- **Tagged sets** (CBOR tag 258 — inputs, collateral, required signers,
  certificates, proposals, scripts) keep the order their elements were given in,
  which for a set read off the wire is the order it was written in. That order is
  part of what a transaction means: the ledger reads a transaction's certificates
  in the order they are listed, and a certificate redeemer's index counts through
  that same order. `asArray` / `asList`, `first` and the subscript all follow it,
  so an element's index is stable. A set built from a Swift `Set` has no order of
  its own and comes out sorted by each element's CBOR encoding, since a `Set`
  iterates differently from one process to the next.
- **A transaction body keeps its field order.** The ledger's own encoder does not
  put the field numbers in ascending order — it writes the required signers before
  the mint, among others — so ``TransactionBody/writtenFieldOrder`` records the
  order a body was read in and re-encodes in it. Fields added afterwards follow in
  numeric order.
- **Redeemer maps** keep the order they were decoded in. This is what
  `script_data_hash` is computed over, and it is taken over the exact bytes.
- **Plutus and metadata maps are lists of pairs.** The ledger reads them that way,
  so their order is part of the value and a key may repeat. ``PlutusData`` and
  ``TransactionMetadatum`` hold their maps as ``MapPairs``, which keeps every
  pair in order; looking a key up gives its first pair's value, as Plutus's
  `lookup` does.
- **Plutus data is read from its bytes** by its own reader, which keeps how each
  list, map, byte string and constructor was written — an indefinite-length
  header, a byte string's chunks, a constructor's general `#6.102` form — and
  rejects what the ledger does not read as Plutus data: text strings, floats,
  simple values and other tags. A byte string stays a byte string, even when its
  content happens to be valid CBOR. Byte strings over 64 bytes built in code are
  written in 64-byte chunks, as the ledger requires.
- **Everything a hash covers keeps the bytes it was read from.** Decoding cannot
  hold every detail of an encoding — the width of an integer's or a length's
  header, for one — so a decoded ``Block``, ``Header``, ``Transaction``,
  ``TransactionBody``, ``TransactionOutput``, ``DatumOption``,
  ``TransactionWitnessSet``, ``AuxiliaryData`` and ``RawPlutusData`` each keep
  their bytes while unchanged, as the witness set does for its datums and
  redeemers. A part that keeps its bytes writes them inside whatever encodes it,
  so changing one part re-encodes that part alone. To compute
  `script_data_hash` from a decoded witness set, take
  ``TransactionWitnessSet/redeemersCBOR()`` and
  ``TransactionWitnessSet/plutusDataCBOR()``; an inline datum's hash is
  ``DatumOption/inlineDatumHash()``; a block's body hash is ``Block/bodyHash()``.
- **A ``PlutusData`` value is exact in what it models, not in header widths.**
  Decoded on its own and re-encoded, it keeps its pairs, chunks and forms, but an
  integer or length written wider than it needs comes back in its shortest form.
  Read a ``RawPlutusData`` to keep those bytes too.
- **A decoded ``Primitive``** keeps indefinite-length byte strings, text strings
  and maps as such. A type that does not care how its value was written reads it
  through ``Primitive/normalized()``.
- **Integers** cover the whole range CBOR carries, down to -2^64, and are
  written as a bignum only beyond it, with a magnitude over 64 bytes in 64-byte
  chunks.
- **Metadata** keeps its label order. Metadata built from a dictionary is written
  in label order, and a byte or text string over 64 bytes is rejected when it is
  built; decoded metadata is not checked, since the ledger did not always
  enforce the limit.
- **Repeated keys and set elements follow the ledger of the era.** Pass the era
  to `fromCBOR(data:era:)` on a ``Transaction``, ``Block`` or one of their parts;
  without one, Conway's rules apply. A sparse record — a body, witness set,
  output, Alonzo auxiliary data or parameter update — may never repeat a field.
  Before Conway an ordinary map keeps a repeated key's later value and a set keeps
  a repeated element once; from Conway both are rejected, except the key
  witnesses, bootstrap witnesses, native scripts and datums of a witness set and
  the keys of its redeemer map, which the ledger still accepts until protocol
  version 12. Plutus data and metadata maps may repeat a key in every era. On
  their own, the generic CBOR decoder rejects any repeated map key.
- **A value outside its field's range fails to decode**, as in the ledger — a
  protocol parameter that is a 16-bit number, say — rather than wrapping or
  crashing. So does a hash of the wrong length: a key hash must be 28 bytes and
  a transaction id 32, and the ledger rejects any other size.
- **Decoding never crashes.** Whatever the input — CBOR bytes, a ``Primitive``,
  JSON — a decoder either produces a value or throws an error, a
  ``CardanoCoreError`` for every check the library makes (see Handling
  Decoding Errors below):
  lengths and counts are checked against the bytes present, and no integer is
  narrowed with a conversion that traps. ``Primitive`` offers
  the same tools to code that reads its own types:
  `integer(_:as:)` reads an integer into a type, throwing when it does not fit,
  and `Primitive.integer(_:)` writes one without trapping.
- **Plutus data, metadata and native scripts of any depth decode**, as the
  ledger reads them with no depth limit — a transaction can nest them as deep as
  its size allows, and a preprod block holds a native script 5,383 levels deep.
  Reading, writing, hashing, `==`, describing and freeing them all run in loops,
  so a value of any depth is safe on a 512 KB thread stack. Their nested lists
  are ``NestedList``s, which read like arrays. Ledger decoding takes CBOR apart
  only 32 levels deep and hands what lies below to these types as its bytes.
  Converting one of them to JSON is bounded: past
  ``PlutusData/maxConversionDepth`` levels `toDict()` throws, and
  `toPrimitive()` gives the encoded bytes instead of a tree.

> Note: `toCBORData(deterministic:)` accepts a flag that is currently ignored.
> Cardano's notion of deterministic encoding (CIP-21) is not RFC 8949 §4.2 — it
> preserves indefinite-length items for PlutusData — so the flag is reserved for a
> Cardano-specific mode rather than CBORCodable's.

### Handling Decoding Errors

A decoder throws a ``CardanoCoreError``; match its cases to tell the failures
apart. Text that is not hex throws `CardanoCoreError.invalidArgument`, and
bytes that are not the CBOR of the type throw
`CardanoCoreError.deserializeError`.

```swift
func decodeTransaction(_ cborHex: String) -> Transaction? {
    do {
        return try Transaction.fromCBORHex(cborHex)
    } catch CardanoCoreError.invalidArgument(let message) {
        print("Not hex: \(message ?? "")")
    } catch CardanoCoreError.deserializeError(let message) {
        print("Not a transaction: \(message ?? "")")
    } catch {
        print("Decoding failed: \(error)")
    }
    return nil
}

assert(decodeTransaction(hex) != nil)
assert(decodeTransaction("not hex") == nil)
assert(decodeTransaction("80") == nil) // an empty CBOR array
```

## Advanced Serialization

### Custom CBOR Encoding

```swift
// Implement CBORSerializable for custom types
struct CustomData: CBORSerializable {
    let value: Int
    let text: String

    init(value: Int, text: String) {
        self.value = value
        self.text = text
    }

    init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .string(stringValue) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid CustomData format")
        }

        self.value = try elements[0].integer("CustomData value")
        self.text = stringValue
    }

    func toPrimitive() throws -> Primitive {
        return .list([
            .integer(value),
            .string(text)
        ])
    }
}

// Usage
let customData = CustomData(value: 42, text: "Hello")
let serialized = try customData.toCBORData()
let deserialized = try CustomData.fromCBOR(data: serialized)
```

### Working with Primitive

A ``Primitive`` holds any CBOR value, for content with no type of its own.

```swift
// Create dynamic CBOR content
let dynamicValue = Primitive.orderedDict([
    .string("name"): .string("Alice"),
    .string("age"): .uint(30),
    .string("tokens"): .list([
        .string("TokenA"),
        .string("TokenB")
    ])
])

let dynamicCBOR = try dynamicValue.toCBORData()
let restored = try Primitive.fromCBOR(data: dynamicCBOR)
```

For code that works with CBORCodable's values, ``Primitive/toAnyValue()``
converts a ``Primitive`` to an ``AnyValue``; no import beyond
`SwiftCardanoCore` is needed.

```swift
let anyValue: AnyValue = restored.toAnyValue()
print("As AnyValue: \(anyValue)")
```

## JSON Serialization

Every type with `toJSON()` reads its JSON back with `fromJSON(_:)` as an equal
value. Bytes are written as hex, as cardano-cli writes them; hex or base64 is
read. A type with no readable JSON form of its own is written as its CBOR shape
when JSON holds that without loss, and as the hex of its CBOR otherwise.

JSON keeps the *value*, not the bytes it was read from. A transaction read back
from JSON is equal to the original, but the way its CBOR was written — map and
field order, indefinite-length lists, chunked byte strings — is not kept, so
re-encoding it can give different bytes, a different transaction id, and
signatures that no longer match. To move a transaction or anything signed,
use its CBOR or a text envelope (`toTextEnvelope()` / `save(to:)`), which keep
the bytes.

### Transaction Metadata JSON

```swift
// Create metadata with JSON-compatible structure
let metadata = try Metadata([
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
let jsonString = try metadata.toJSON()!
print("Metadata JSON: \(jsonString)")

// Parse from JSON
let parsedMetadata = try Metadata.fromJSON(jsonString)
```

### PlutusData JSON

```swift
// Convert PlutusData to/from JSON (cardano-cli's detailed schema)
let plutusData = PlutusData.constructor(Constr(tag: 0, fields: [
    .bigInt(.int(42)),
    .bytes(try Bytes(from: Data("hello".utf8))),
    .array([.bigInt(.int(1)), .bigInt(.int(2)), .bigInt(.int(3))]),
]))

let plutusJSON = try plutusData.toJSON()!
let fromJSON = try PlutusData.fromJSON(plutusJSON)
```

### Your Own Plutus Data Types

A type of your own conforms to ``PlutusDataProtocol`` by converting to and
from ``PlutusData``. It then gets CBOR and JSON encoding, `fromJSON(_:)`, its
datum hash and `==` from the protocol.

```swift
// A datum with three fields: constructor 0 of an integer, bytes and a list
struct MyPlutusData: PlutusDataProtocol {
    let field1: Int64
    let field2: Data
    let field3: [Int64]

    init(field1: Int64, field2: Data, field3: [Int64]) {
        self.field1 = field1
        self.field2 = field2
        self.field3 = field3
    }

    init(from plutusData: PlutusData) throws {
        guard case let .constructor(constr) = plutusData,
              constr.tag == 0,
              constr.fields.count == 3,
              case let .bigInt(.int(field1)) = constr.fields[0],
              case let .bytes(field2) = constr.fields[1],
              case let .array(list) = constr.fields[2] else {
            throw CardanoCoreError.deserializeError("Invalid MyPlutusData: \(plutusData)")
        }
        self.field1 = field1
        self.field2 = field2.data
        self.field3 = try list.map { element in
            guard case let .bigInt(.int(value)) = element else {
                throw CardanoCoreError.deserializeError("Invalid MyPlutusData list element: \(element)")
            }
            return value
        }
    }

    func toPlutusData() throws -> PlutusData {
        .constructor(Constr(tag: 0, fields: [
            .bigInt(.int(field1)),
            .bytes(try Bytes(from: field2)),
            .array(NestedList(field3.map { .bigInt(.int($0)) })),
        ]))
    }
}

let myData = MyPlutusData(field1: 42, field2: Data("hello".utf8), field3: [1, 2, 3])

// JSON (cardano-cli's detailed schema) and back
let myJSON = try myData.toJSON()!
let myFromJSON = try MyPlutusData.fromJSON(myJSON)
assert(myFromJSON == myData)

// CBOR and the datum hash, as for any Plutus data
let myCBOR = try myData.toCBORData()
let myFromCBOR = try MyPlutusData.fromCBOR(data: myCBOR)
let myDatumHash = try myData.hash()
```

## File Operations

### Text Envelope Files

Transactions, keys, certificates and the other types that conform to ``TextEnvelopable`` save to and load from JSON text-envelope files compatible with Cardano CLI tools.

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
let loadedTransaction = try Transaction.load(from: "my-transaction.tx")
print("Transaction loaded: \(loadedTransaction.id?.payload.toHex ?? "unknown")")

// Verify integrity
assert(transaction.id == loadedTransaction.id)
```

### Address File Operations

Addresses save as their Bech32 text. This example assumes a script's
`scriptHash`.

```swift
// Save different address types
let paymentAddr = try Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
let stakeAddr = try Address.fromBech32("stake_test1uqevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqp8n5xl")
let scriptAddr = try Address(paymentPart: .scriptHash(scriptHash), network: .testnet)

// Save addresses to files
try paymentAddr.save(to: "payment.addr")
try stakeAddr.save(to: "stake.addr")
try scriptAddr.save(to: "script.addr")

// Load addresses from files
let loadedPayment = try Address.load(from: "payment.addr")
let loadedStake = try Address.load(from: "stake.addr")
let loadedScript = try Address.load(from: "script.addr")

// Verify addresses match
assert(paymentAddr == loadedPayment)
assert(stakeAddr == loadedStake)
assert(scriptAddr == loadedScript)
```


### Metadata File Operations

Metadata has no text envelope; ``Metadata`` saves and loads its JSON form
with `saveJSON(to:)` and `loadJSON(from:)`.

```swift
// Create rich metadata
let nftMetadata = try Metadata([
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
try nftMetadata.saveJSON(to: "nft-metadata.json")

// Load and verify metadata
let loadedMetadata = try Metadata.loadJSON(from: "nft-metadata.json")
let originalJSON = try nftMetadata.toJSON()
let loadedJSON = try loadedMetadata.toJSON()

// JSON should be identical
assert(originalJSON == loadedJSON)
```

### Certificate File Operations

This example assumes the pool's `poolKeyHash`, `vrfKeyHash`,
`rewardAccountHash`, `ownerKeyHash`, `relay` and `poolMetadata`; see
<doc:StakePools> for how to make them.

```swift
// Create stake pool registration certificate
let poolParams = PoolParams(
    poolOperator: poolKeyHash,
    vrfKeyHash: vrfKeyHash,
    pledge: Coin(1000000000), // 1000 ADA
    cost: Coin(340000000),    // 340 ADA
    margin: UnitInterval(numerator: 1, denominator: 20), // 5%
    rewardAccount: rewardAccountHash,
    poolOwners: .list([ownerKeyHash]),
    relays: [relay],
    poolMetadata: poolMetadata
)

let poolRegistration = try PoolRegistration(poolParams: poolParams)

// Save certificate to file
try poolRegistration.save(to: "pool-registration.cert")

// Load certificate from file
let loadedCert = try PoolRegistration.load(from: "pool-registration.cert")
```


## See Also

- <doc:Transactions> - Transaction serialization examples
- <doc:Scripts> - PlutusData serialization
- <doc:Assets> - Value and asset encoding

## Related Symbols

- ``CBORSerializable``
- ``Primitive``
- ``AnyValue``
- ``Metadata``
- ``PlutusData``
- ``PlutusDataProtocol``
- ``CardanoCoreError``
