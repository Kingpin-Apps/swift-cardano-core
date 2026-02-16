# Stake Pools

Set up and manage Cardano stake pool node operations, including key management, operational certificates, and pool registration.

## Overview

Running a Cardano stake pool requires managing several cryptographic components: cold keys for pool identity, KES (Key Evolving Signature) keys for forward-secure block signing, VRF (Verifiable Random Function) keys for leader election, and operational certificates that bind these together. SwiftCardanoCore provides comprehensive support for all stake pool operations, matching the functionality of `cardano-cli node` commands.

## Key Types & Concepts

### Node Keys

- ``StakePoolSigningKey`` & ``StakePoolVerificationKey``: Cold keys that represent pool identity (Ed25519)
- ``StakePoolKeyPair``: Combined cold signing and verification keys
- ``KESSigningKey`` & ``KESVerificationKey``: Hot keys for forward-secure block signing (Sum6KES)
- ``KESKeyPair``: Combined KES signing and verification keys
- ``VRFSigningKey`` & ``VRFVerificationKey``: Keys for verifiable random leader selection
- ``VRFKeyPair``: Combined VRF signing and verification keys

### Operational Certificates

- ``OperationalCertificate``: Binds a KES hot key to a pool's cold key with an Ed25519 signature
- ``OperationalCertificateIssueCounter``: Tracks the monotonically increasing sequence number for certificate issuance

### Pool Registration

- ``PoolParams``: Complete set of parameters required for pool registration
- ``PoolOperator``: Pool identity (key hash) with bech32 encoding support
- ``PoolMetadata``: Off-chain pool metadata (name, description, ticker, homepage)
- ``Relay``: Network relay configuration for the pool
- ``SingleHostAddr``: Relay with IP address and port
- ``SingleHostName``: Relay with DNS hostname and port
- ``MultiHostName``: Relay with DNS SRV record

## Step-by-Step Node Setup

### 1. Generate Cold Keys

Cold keys represent the pool's long-term identity and must be kept secure offline.

```swift
import SwiftCardanoCore

// Generate cold key pair
let coldKeyPair = try StakePoolKeyPair.generate()

// Save keys in Cardano CLI-compatible format
try coldKeyPair.signingKey.save(to: "cold.skey")
try coldKeyPair.verificationKey.save(to: "cold.vkey")

// Derive the pool ID
let poolKeyHash = try coldKeyPair.verificationKey.poolKeyHash()
let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
print("Pool ID: \(try poolOperator.toBech32())")
```

### 2. Generate KES Keys

KES keys provide forward security: after evolving to a new period, old key material is securely erased.

```swift
// Generate KES key pair
let kesKeyPair = try KESKeyPair.generate()

// Save keys
try kesKeyPair.signingKey.save(to: "kes.skey")
try kesKeyPair.verificationKey.save(to: "kes.vkey")

// KES keys support 64 signing periods (Sum6KES depth 6)
print("Total KES periods: \(KESSigningKey.totalPeriods)") // 64
```

### 3. Generate VRF Keys

VRF keys are used for the slot leader election lottery.

```swift
// Generate VRF key pair
let vrfKeyPair = try VRFKeyPair.generate()

// Save keys
try vrfKeyPair.signingKey.save(to: "vrf.skey")
try vrfKeyPair.verificationKey.save(to: "vrf.vkey")

// Get VRF key hash for pool registration
let vrfKeyHash = try vrfKeyPair.verificationKey.hash()
```

### 4. Create Issue Counter

The issue counter must increment by exactly one for each new operational certificate.

```swift
// Create a new counter (starts at 0)
var issueCounter = try OperationalCertificateIssueCounter.createNewCounter(
    coldVerificationKey: coldKeyPair.verificationKey
)

// Save in Cardano CLI-compatible format
try issueCounter.save(to: "opcert.counter")

// Load an existing counter
var loadedCounter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")
```

### 5. Issue an Operational Certificate

The operational certificate binds the KES hot key to the pool's cold key identity.

```swift
// Issue a new operational certificate
let kesPeriod: UInt64 = 0 // Current KES period

let opcert = try OperationalCertificate.issue(
    kesVerificationKey: kesKeyPair.verificationKey,
    coldSigningKey: coldKeyPair.signingKey,
    operationalCertificateIssueCounter: &issueCounter,
    kesPeriod: kesPeriod
)

// Save the certificate and updated counter
try opcert.save(to: "node.cert")
try issueCounter.save(to: "opcert.counter", overwrite: true)

// The counter was automatically incremented
print("Next sequence number: \(issueCounter.counterValue)") // 1
```

## Key Rotation

Cardano requires periodic key rotation to maintain pool security. When the current KES key approaches its maximum period (64 periods for Sum6KES), pool operators must generate fresh KES and VRF keys and issue a new operational certificate. The cold keys remain the same — they represent the pool's permanent identity.

```swift
// 1. Generate new KES keys
let newKesKeyPair = try KESKeyPair.generate()
try newKesKeyPair.signingKey.save(to: "kes.skey", overwrite: true)
try newKesKeyPair.verificationKey.save(to: "kes.vkey", overwrite: true)

// 2. Generate new VRF keys
let newVrfKeyPair = try VRFKeyPair.generate()
try newVrfKeyPair.signingKey.save(to: "vrf.skey", overwrite: true)
try newVrfKeyPair.verificationKey.save(to: "vrf.vkey", overwrite: true)

// 3. Load the existing counter and cold signing key
var counter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")
let coldSKey = try StakePoolSigningKey.load(from: "cold.skey")

// 4. Issue a new operational certificate with the new KES key
let currentKesPeriod: UInt64 = 64 // The KES period at rotation time
let newCert = try OperationalCertificate.issue(
    kesVerificationKey: newKesKeyPair.verificationKey,
    coldSigningKey: coldSKey,
    operationalCertificateIssueCounter: &counter,
    kesPeriod: currentKesPeriod
)

// 5. Save the new certificate and updated counter
try newCert.save(to: "node.cert", overwrite: true)
try counter.save(to: "opcert.counter", overwrite: true)

// 6. Restart the node with the new files
```

## Pool Registration

### Configure Pool Parameters

```swift
// Pool metadata (hosted off-chain)
let poolMetadata = try PoolMetadata(
    url: Url("https://example.com/pool-metadata.json"),
    poolMetadataHash: PoolMetadataHash(payload: metadataHashBytes)
)

// Configure relay endpoints
let relay = Relay.singleHostAddr(
    SingleHostAddr(port: 6000, ipv4: ipv4Data, ipv6: nil)
)

// Build pool parameters
let poolParams = PoolParams(
    poolOperator: try coldKeyPair.verificationKey.poolKeyHash(),
    vrfKeyHash: try vrfKeyPair.verificationKey.hash(),
    pledge: 100_000_000_000, // 100,000 ADA in lovelace
    cost: 340_000_000,       // 340 ADA minimum cost
    margin: UnitInterval(numerator: 3, denominator: 100), // 3% margin
    rewardAccount: rewardAccountHash,
    poolOwners: .orderedSet(OrderedSet([ownerKeyHash])),
    relays: [relay],
    poolMetadata: poolMetadata
)
```

### Pool Metadata

```swift
// Create pool metadata for off-chain hosting
let metadata = try PoolMetadata(
    name: "My Stake Pool",
    description: "A reliable Cardano stake pool",
    ticker: "MYSP",
    homepage: Url("https://example.com")
)

// Compute the metadata hash (must be under 512 bytes)
let metadataHash = try metadata.hash()
print("Metadata hash: \(metadataHash)")

// Serialize to JSON for hosting
let json = try metadata.toJSON()
```

### Pool Operator Identity

```swift
// Create from bech32 pool ID
let poolOp = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")

// Create from key hash
let poolOpFromHash = try PoolOperator(from: poolKeyHash.payload)

// Get pool ID in different formats
let bech32Id = try poolOp.toBech32()
let hexId = try poolOp.id(.hex)

// Validate a pool ID
let isValid = PoolOperator.isValidBech32("pool1pu5jlj...")

// Save and load pool ID
try poolOp.save(to: "pool.id", format: .bech32)
let loaded = try PoolOperator.load(from: "pool.id")
```

## Operational Certificate Management

### Loading and Inspecting Certificates

```swift
// Load an existing operational certificate
let cert = try OperationalCertificate.load(from: "node.cert")

print("KES VKey: \(cert.hotVKey.payload.toHex)")
print("Sequence: \(cert.sequenceNumber)")
print("KES Period: \(cert.kesPeriod)")
print("Sigma: \(cert.sigma.toHex)")

if let coldVKey = cert.coldVerificationKey {
    print("Cold VKey: \(coldVKey.payload.toHex)")
}
```

### Counter Validation

```swift
// Validate the counter's cold key matches a signing key
let isValid = issueCounter.validateVerificationKey(coldKeyPair.verificationKey)

// Inspect counter state
print("Counter value: \(issueCounter.counterValue)")
print("Cold VKey: \(issueCounter.coldVerificationKey.payload.toHex)")
```

## Serialization & Cardano CLI Compatibility

All stake pool types support Cardano CLI-compatible text envelope format for seamless interoperability.

```swift
// Text envelope save and load (Cardano CLI format)
try opcert.save(to: "node.cert")
let loadedCert = try OperationalCertificate.load(from: "node.cert")

try issueCounter.save(to: "opcert.counter")
let loadedCounter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")

// CBOR hex encoding
let cborHex = try opcert.toCBORHex()
let fromHex = try OperationalCertificate.fromCBORHex(cborHex)

// JSON serialization
let json = try opcert.toJSON()
let fromJson = try OperationalCertificate.fromJSON(json!)
```

## Error Handling

```swift
do {
    let opcert = try OperationalCertificate.issue(
        kesVerificationKey: kesKeyPair.verificationKey,
        coldSigningKey: coldKeyPair.signingKey,
        operationalCertificateIssueCounter: &issueCounter,
        kesPeriod: kesPeriod
    )
    try opcert.save(to: "node.cert")

} catch CardanoCoreError.invalidArgument(let message) {
    print("Invalid parameter: \(message)")
} catch CardanoCoreError.deserializeError(let message) {
    print("Deserialization failed: \(message)")
} catch CardanoCoreError.ioError(let message) {
    print("File operation failed: \(message)")
} catch CardanoCoreError.valueError(let message) {
    print("Validation error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## See Also

- <doc:Keys> - Cryptographic key generation and management
- <doc:Certificates> - Pool registration and retirement certificates
- <doc:Transactions> - Including pool operations in transactions
- <doc:Serialization> - CBOR and text envelope formats

## Related Symbols

- ``OperationalCertificate``
- ``OperationalCertificateIssueCounter``
- ``StakePoolKeyPair``
- ``KESKeyPair``
- ``VRFKeyPair``
- ``PoolParams``
- ``PoolOperator``
- ``PoolMetadata``
- ``Relay``
