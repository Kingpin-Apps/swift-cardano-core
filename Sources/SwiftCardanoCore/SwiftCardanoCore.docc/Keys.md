# Keys

Generate, manage, and use cryptographic keys for Cardano transactions and operations.

## Overview

Cardano uses Ed25519 elliptic curve cryptography for all key operations. SwiftCardanoCore provides comprehensive support for generating, storing, and using various types of cryptographic keys required for different Cardano operations.

## Key Types & Concepts

### Core Key Types

- ``PaymentSigningKey`` & ``PaymentVerificationKey``: Authorize transaction spending
- ``StakeSigningKey`` & ``StakeVerificationKey``: Manage staking operations
- ``StakePoolSigningKey`` & ``StakePoolVerificationKey``: Operate stake pools
- ``VRFSigningKey`` & ``VRFVerificationKey``: Generate verifiable random functions
- ``DRepSigningKey`` & ``DRepVerificationKey``: Governance operations

### Key Pair Conveniences

- ``PaymentKeyPair``: Combined payment signing and verification keys
- ``StakeKeyPair``: Combined stake signing and verification keys
- ``StakePoolKeyPair``: Combined pool operator keys
- ``VRFKeyPair``: Combined VRF keys
- ``DRepKeyPair``: Combined governance keys

### Extended Keys

- ``PaymentExtendedSigningKey`` & ``PaymentExtendedVerificationKey``: BIP32 hierarchical keys
- ``StakeExtendedSigningKey`` & ``StakeExtendedVerificationKey``: Extended stake keys
- ``HDWallet``: Derives extended keys from a mnemonic along a BIP32 path

## Step-by-Step Key Management

These examples are compiled and run by the package's tests
(`KeysGuideExamplesTests`), so they stay true to the API.

### 1. Generating Keys

```swift
import SwiftCardanoCore

// Individual key generation
let paymentSKey = try PaymentSigningKey.generate()
let paymentVKey = try PaymentVerificationKey.fromSigningKey(paymentSKey)

let stakeSKey = try StakeSigningKey.generate()
let stakeVKey = try StakeVerificationKey.fromSigningKey(stakeSKey)

// KeyPair generation (recommended)
let paymentKeyPair = try PaymentKeyPair.generate()
let stakeKeyPair = try StakeKeyPair.generate()

print("Payment Key Generated: \(paymentKeyPair.verificationKey.payload.toHex)")
print("Stake Key Generated: \(stakeKeyPair.verificationKey.payload.toHex)")
```

### 2. Key Persistence

```swift
// Save keys to files (Cardano CLI compatible format)
try paymentKeyPair.signingKey.save(to: "payment.skey")
try paymentKeyPair.verificationKey.save(to: "payment.vkey")
try stakeKeyPair.signingKey.save(to: "stake.skey")
try stakeKeyPair.verificationKey.save(to: "stake.vkey")

// Load keys from files
let loadedPaymentSKey = try PaymentSigningKey.load(from: "payment.skey")
let loadedPaymentVKey = try PaymentVerificationKey.load(from: "payment.vkey")
let loadedStakeSKey = try StakeSigningKey.load(from: "stake.skey")
let loadedStakeVKey = try StakeVerificationKey.load(from: "stake.vkey")

// Verify loaded keys match
assert(loadedPaymentSKey == paymentKeyPair.signingKey)
assert(loadedPaymentVKey == paymentKeyPair.verificationKey)
```

### 3. Key Derivation and Validation

```swift
// Derive verification key from signing key
let derivedVKey = try PaymentVerificationKey.fromSigningKey(paymentSKey)

// Generate key hashes for addresses
let paymentKeyHash = try paymentKeyPair.verificationKey.hash()
let stakeKeyHash = try stakeKeyPair.verificationKey.hash()

print("Payment Key Hash: \(paymentKeyHash.payload.toHex)")
print("Stake Key Hash: \(stakeKeyHash.payload.toHex)")

// Sign a message (a 64-byte Ed25519 signature) and verify the signature
let testData = Data("test message".utf8)
let signature = try paymentKeyPair.signingKey.sign(data: testData)
let isValid = try paymentKeyPair.verificationKey.verify(signature: signature, data: testData)
assert(isValid)

// A signature does not verify for any other message
let isTampered = try paymentKeyPair.verificationKey.verify(
    signature: signature,
    data: Data("tampered message".utf8)
)
assert(!isTampered)
```

`verify(signature:data:)` checks an Ed25519 signature. Every Ed25519
verification key has it, the extended ones too; it throws
`CardanoCoreError.invalidKeyTypeError` when the key is not a 32-byte Ed25519
key. (KES keys verify with `verify(signature:message:period:)` instead.)

## Advanced Key Operations

### Extended Keys (BIP32)

`generate()` makes a standalone extended key: the root key of a wallet made
from fresh entropy.

```swift
// Generate extended keys
let rootPaymentSKey = try PaymentExtendedSigningKey.generate()
let rootStakeSKey = try StakeExtendedSigningKey.generate()

// Their verification keys carry the chain code
let rootPaymentVKey = try PaymentExtendedVerificationKey.fromSigningKey(rootPaymentSKey)
let rootStakeVKey = try StakeExtendedVerificationKey.fromSigningKey(rootStakeSKey)

// Extended keys sign and verify like the others
let message = Data("extended message".utf8)
let rootSignature = try rootPaymentSKey.sign(data: message)
assert(try rootPaymentVKey.verify(signature: rootSignature, data: message))
```

To derive keys along a path instead, as a wallet does, start from a mnemonic:

```swift
// Create a wallet from a new 24-word mnemonic
let mnemonic = try HDWallet.generateMnemonic().joined(separator: " ")
let wallet = try HDWallet.fromMnemonic(mnemonic: mnemonic)

// Derive the first payment and stake keys of account 0 (CIP-1852)
let paymentWallet = try wallet.derive(fromPath: "m/1852'/1815'/0'/0/0")
let stakeWallet = try wallet.derive(fromPath: "m/1852'/1815'/0'/2/0")

let extendedPaymentKey = try PaymentExtendedSigningKey.fromHDWallet(paymentWallet)
let extendedStakeKey = try StakeExtendedSigningKey.fromHDWallet(stakeWallet)

// The extended verification key carries the chain code
let extendedPaymentVKey = try PaymentExtendedVerificationKey.fromSigningKey(extendedPaymentKey)
```

### Specialized Keys

```swift
// Stake pool keys
let poolKeyPair = try StakePoolKeyPair.generate()
let vrfKeyPair = try VRFKeyPair.generate()

// Pool key hash for registration
let poolKeyHash = try poolKeyPair.verificationKey.poolKeyHash()
let vrfKeyHash = try vrfKeyPair.verificationKey.hash()

// DRep keys for governance
let drepKeyPair = try DRepKeyPair.generate()
let drepKeyHash = try drepKeyPair.verificationKey.hash()

// Committee keys
let committeeColdKeyPair = try CommitteeColdKeyPair.generate()
let committeeHotKeyPair = try CommitteeHotKeyPair.generate()
```

### Key Security

```swift
// Secure key generation with entropy
func generateSecureKeyPair() throws -> PaymentKeyPair {
    // SwiftCardanoCore uses secure random number generation internally
    return try PaymentKeyPair.generate()
}

// Key validation: the verification key must verify the signing key's signatures
func validateKeyPair(_ keyPair: PaymentKeyPair) throws {
    let testMessage = Data("validation test".utf8)
    let signature = try keyPair.signingKey.sign(data: testMessage)

    guard try keyPair.verificationKey.verify(signature: signature, data: testMessage) else {
        throw CardanoCoreError.invalidArgument("Key pair validation failed")
    }
}

try validateKeyPair(paymentKeyPair)
```

## Key-Based Operations

These examples assume a `txBody` of your own.

### Transaction Signing

```swift
// Sign transaction data
let txBodyHash = try txBody.hash()
let signature = try paymentKeyPair.signingKey.sign(data: txBodyHash)

// Create witness for transaction
let witness = VerificationKeyWitness(
    vkey: .verificationKey(paymentKeyPair.verificationKey),
    signature: signature
)
```

### Multi-Signature Setup

```swift
// Generate multiple key pairs for multi-sig
let keyPairs = try (0..<3).map { _ in try PaymentKeyPair.generate() }
let keyHashes = try keyPairs.map { try $0.verificationKey.hash() }

// Create multi-signature script (2-of-3)
let multiSigScript = NativeScript.scriptNofK(ScriptNofK(
    required: 2,
    scripts: keyHashes.map { keyHash in
        .scriptPubkey(ScriptPubkey(keyHash: keyHash))
    }
))

// Sign with multiple keys
let signatures = try keyPairs.map { keyPair in
    try keyPair.signingKey.sign(data: txBodyHash)
}
```

## Error Handling

Key operations throw a ``CardanoCoreError``; match its cases to tell the
failures apart. `save(to:)` throws `CardanoCoreError.ioError` when the file
already exists (pass `overwrite: true` to replace it).

```swift
do {
    let keyPair = try PaymentKeyPair.generate()
    try keyPair.signingKey.save(to: "payment.skey")

    let signature = try keyPair.signingKey.sign(data: Data("test message".utf8))
    print("Signature: \(signature.toHex)")
} catch CardanoCoreError.ioError(let message) {
    print("File operation failed: \(message ?? "")")
} catch CardanoCoreError.invalidKeyTypeError(let message) {
    print("Wrong kind of key: \(message ?? "")")
} catch {
    print("Key operation error: \(error)")
}
```

## Best Practices

### Secure Key Storage

```swift
// Store keys securely with proper file permissions
func saveKeySecurely<T: SigningKeyProtocol>(_ key: T, to path: String) throws {
    try key.save(to: path)
    
    // Set restrictive file permissions (Unix-like systems)
    let fileURL = URL(fileURLWithPath: path)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600], // Owner read/write only
        ofItemAtPath: fileURL.path
    )
}

try saveKeySecurely(paymentKeyPair.signingKey, to: "secure_payment.skey")
```


## Testing and Validation

```swift
// Key generation testing
func testKeyGeneration() throws {
    let keyPair1 = try PaymentKeyPair.generate()
    let keyPair2 = try PaymentKeyPair.generate()
    
    // Keys should be different
    assert(keyPair1.signingKey != keyPair2.signingKey)
    assert(keyPair1.verificationKey != keyPair2.verificationKey)
    
    // Derived verification key should match
    let derivedVKey = try PaymentVerificationKey.fromSigningKey(keyPair1.signingKey)
    assert(derivedVKey == keyPair1.verificationKey)
}

// Round-trip serialization testing
func testKeySerialization() throws {
    let originalKey = try PaymentSigningKey.generate()
    
    // Serialize and deserialize
    let serialized = try originalKey.toCBORData()
    let deserialized = try PaymentSigningKey.fromCBOR(data: serialized)
    
    // Should be identical
    assert(originalKey == deserialized)
}
```

## See Also

- <doc:Addresses> - Creating addresses from keys
- <doc:Transactions> - Signing transactions with keys
- <doc:Certificates> - Key-based certificate operations
- <doc:Scripts> - Multi-signature scripts

## Related Symbols

- ``PaymentKeyPair``
- ``StakeKeyPair``
- ``PaymentSigningKey``
- ``PaymentVerificationKey``
- ``StakeSigningKey``
- ``StakeVerificationKey``
- ``VerificationKeyHash``
- ``PaymentExtendedSigningKey``
- ``HDWallet``
- ``CardanoCoreError``
