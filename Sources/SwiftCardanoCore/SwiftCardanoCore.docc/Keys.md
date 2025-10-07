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

## Step-by-Step Key Management

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

// Validate key pair consistency
let testData = Data("test message".utf8)
let signature = try paymentKeyPair.signingKey.sign(data: testData)
let isValid = try paymentKeyPair.verificationKey.verify(signature: signature, data: testData)
assert(isValid)
```

## Advanced Key Operations

### Extended Keys (BIP32)

```swift
// Generate extended keys for hierarchical derivation
let extendedPaymentKey = try PaymentExtendedSigningKey.generate()
let extendedStakeKey = try StakeExtendedSigningKey.generate()

// Derive child keys (implementation depends on BIP32 support)
// let childKey = try extendedPaymentKey.deriveChild(index: 0)
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

// Key validation
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

### Transaction Signing

```swift
// Sign transaction data
let txBodyHash = txBody.hash()
let signature = try paymentKeyPair.signingKey.sign(data: txBodyHash)

// Create witness for transaction
let witness = VerificationKeyWitness(
    vkey: .verificationKey(VerificationKey(
        payload: paymentKeyPair.verificationKey.payload,
        type: paymentKeyPair.verificationKey.type,
        description: paymentKeyPair.verificationKey.description
    )),
    signature: signature
)
```

### Multi-Signature Setup

```swift
// Generate multiple key pairs for multi-sig
let keyPairs = try (0..<3).map { _ in try PaymentKeyPair.generate() }
let keyHashes = try keyPairs.map { try $0.verificationKey.hash() }

// Create multi-signature script (2-of-3)
let multiSigScript = NativeScript.scriptNOfK(
    n: 2,
    nativeScripts: keyHashes.map { keyHash in
        .scriptPubkey(.verificationKeyHash(keyHash))
    }
)

// Sign with multiple keys
let signatures = try keyPairs.map { keyPair in
    try keyPair.signingKey.sign(data: txBodyHash)
}
```

## Error Handling

```swift
do {
    let keyPair = try PaymentKeyPair.generate()
    try keyPair.signingKey.save(to: "payment.skey")
    
    let signature = try keyPair.signingKey.sign(data: testData)
    
} catch CardanoCoreError.invalidArgument(let message) {
    print("Invalid key parameter: \(message)")
} catch CardanoCoreError.ioError(let message) {
    print("File operation failed: \(message)")
} catch CardanoCoreError.encodingError(let message) {
    print("Key encoding failed: \(message)")
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
