# Certificates

Create and manage Cardano certificates for staking, governance, and pool operations.

## Overview

Certificates are special transaction components that enable staking operations, pool management, and governance participation on the Cardano blockchain. SwiftCardanoCore provides comprehensive support for all certificate types across different Cardano eras.

## Key Types & Concepts

### Certificate Types

- ``Certificate``: The main certificate enum containing all certificate variants
- ``StakeRegistrationCertificate``: Register a stake address for staking
- ``StakeDelegationCertificate``: Delegate stake to a pool
- ``StakeDeregistrationCertificate``: Unregister a stake address
- ``PoolRegistrationCertificate``: Register a new stake pool
- ``PoolRetirementCertificate``: Retire an existing stake pool

### Governance Certificates

- ``RegisterDRepCertificate``: Register as a Delegated Representative
- ``UnregisterDRepCertificate``: Unregister a DRep
- ``UpdateDRepCertificate``: Update DRep information
- ``VoteDelegateCertificate``: Delegate voting power

### Committee Certificates

- ``AuthCommitteeHotCertificate``: Authorize committee hot key
- ``ResignCommitteeColdCertificate``: Resign from committee

## Step-by-Step Certificate Creation

### 1. Stake Registration

```swift
import SwiftCardanoCore

// Generate stake keys
let stakeKeyPair = try StakeKeyPair.generate()

// Create stake credential
let stakeCredential = Credential.verificationKeyHash(try stakeKeyPair.verificationKey.hash())

// Create registration certificate
let stakeRegistration = StakeRegistrationCertificate(
    stakeCredential: stakeCredential,
    coin: Coin(2_000_000) // Registration deposit (2 ADA)
)

let certificate = Certificate.stakeRegistration(stakeRegistration)
```

### 2. Stake Delegation

```swift
// Pool ID to delegate to
let poolKeyHash = try PoolKeyHash(from: .string("pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy"))

// Create delegation certificate
let stakeDelegation = StakeDelegationCertificate(
    stakeCredential: stakeCredential,
    poolKeyHash: poolKeyHash
)

let delegationCert = Certificate.stakeDelegation(stakeDelegation)
```

### 3. Combined Registration and Delegation

```swift
// Modern approach: register and delegate in one certificate
let stakeRegisterDelegate = StakeRegisterDelegateCertificate(
    stakeCredential: stakeCredential,
    poolKeyHash: poolKeyHash,
    coin: Coin(2_000_000) // Registration deposit
)

let combinedCert = Certificate.stakeRegisterDelegate(stakeRegisterDelegate)
```

## Pool Operations

### Pool Registration

```swift
// Generate pool keys
let poolKeyPair = try StakePoolKeyPair.generate()
let vrfKeyPair = try VRFKeyPair.generate()

// Pool metadata
let poolMetadata = PoolMetadata(
    url: try Url("https://example.com/pool-metadata.json"),
    hash: MetadataHash(payload: Data(repeating: 0x01, count: 32))
)

// Pool parameters
let poolParams = PoolParams(
    operator: try poolKeyPair.verificationKey.poolKeyHash(),
    vrfKeyHash: try vrfKeyPair.verificationKey.hash(),
    pledge: Coin(100_000_000_000), // 100,000 ADA
    cost: Coin(340_000_000), // 340 ADA minimum
    margin: UnitInterval(numerator: 3, denominator: 100), // 3% margin
    rewardAccount: RewardAccount(Data(repeating: 0x02, count: 29)),
    poolOwners: [try stakeKeyPair.verificationKey.hash()],
    relays: [], // Add relay information as needed
    poolMetadata: poolMetadata
)

// Create pool registration certificate
let poolRegistration = PoolRegistrationCertificate(poolParams: poolParams)
let poolRegCert = Certificate.poolRegistration(poolRegistration)
```

### Pool Retirement

```swift
// Retire pool at specific epoch
let poolRetirement = PoolRetirementCertificate(
    poolKeyHash: try poolKeyPair.verificationKey.poolKeyHash(),
    epoch: 350 // Retirement epoch
)

let poolRetireCert = Certificate.poolRetirement(poolRetirement)
```

## Governance Certificates

### DRep Registration

```swift
// Generate DRep keys
let drepKeyPair = try DRepKeyPair.generate()

// Create DRep registration certificate
let drepRegistration = RegisterDRepCertificate(
    votingCredential: Credential.verificationKeyHash(try drepKeyPair.verificationKey.hash()),
    coin: Coin(500_000_000), // DRep deposit (500 ADA)
    anchor: Anchor(
        anchorUrl: try Url("https://example.com/drep-metadata.json"),
        anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x03, count: 32))
    )
)

let drepRegCert = Certificate.registerDRep(drepRegistration)
```

### Vote Delegation

```swift
// Delegate voting power to a DRep
let voteDelegation = VoteDelegateCertificate(
    stakeCredential: stakeCredential,
    dRep: .drepKeyHash(try drepKeyPair.verificationKey.hash())
)

let voteDelegationCert = Certificate.voteDelegate(voteDelegation)

// Alternative: delegate to always abstain
let alwaysAbstainDelegation = VoteDelegateCertificate(
    stakeCredential: stakeCredential,
    dRep: .alwaysAbstain
)

let abstainCert = Certificate.voteDelegate(alwaysAbstainDelegation)
```

## Advanced Certificate Features

### Multiple Certificates in Transaction

```swift
// Create transaction with multiple certificates
let certificates: [Certificate] = [
    certificate, // Stake registration
    delegationCert, // Stake delegation
    voteDelegationCert // Vote delegation
]

let txBody = TransactionBody(
    inputs: .orderedSet(try OrderedSet([txInput])),
    outputs: [txOutput],
    fee: Coin(500_000), // Higher fee for multiple certificates
    certificates: .nonEmptyOrderedSet(NonEmptyOrderedSet(certificates))
)
```

## Certificate Serialization

### CBOR Encoding

```swift
// Serialize individual certificate
let cborData = try certificate.toCBORData()
let cborHex = try certificate.toCBORHex()

// Serialize certificate array
let certificatesData = try certificates.toCBORData()
```

### Save and Load Methods

Certificates conform to the ``PayloadJSONSerializable`` protocol, providing convenient methods for saving to and loading from JSON files in Cardano CLI-compatible format.

```swift
// Create a certificate
let stakeKeyPair = try StakeKeyPair.generate()
let stakeCredential = Credential.verificationKeyHash(try stakeKeyPair.verificationKey.hash())
let stakeRegistration = StakeRegistrationCertificate(
    stakeCredential: stakeCredential,
    coin: Coin(2_000_000)
)

// Save certificate to file
try stakeRegistration.save(to: "stake-registration.cert")
print("Certificate saved to stake-registration.cert")

// Load certificate from file
let loadedCertificate = try StakeRegistrationCertificate.load(from: "stake-registration.cert")
print("Certificate loaded successfully")

// Verify they match
assert(stakeRegistration == loadedCertificate)
```

### File Format Compatibility

The save and load methods are fully compatible with Cardano CLI certificate files:

```swift
// Save different certificate types
let poolKeyHash = try PoolKeyHash(from: .string("pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy"))
let delegationCert = StakeDelegationCertificate(
    stakeCredential: stakeCredential,
    poolKeyHash: poolKeyHash
)

let drepKeyPair = try DRepKeyPair.generate()
let drepCert = RegisterDRepCertificate(
    votingCredential: Credential.verificationKeyHash(try drepKeyPair.verificationKey.hash()),
    coin: Coin(500_000_000),
    anchor: Anchor(
        anchorUrl: try Url("https://example.com/drep-metadata.json"),
        anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x03, count: 32))
    )
)

// Save certificates to files
try delegationCert.save(to: "stake-delegation.cert")
try drepCert.save(to: "drep-registration.cert")

// These files can be used directly with cardano-cli commands
```


### Error Handling with File Operations

```swift
do {
    // Save certificate
    try certificate.save(to: "my-certificate.cert")
    
    // Load certificate
    let loadedCert = try Certificate.load(from: "my-certificate.cert")
    print("Certificate loaded successfully")
    
    // Validate certificate
    try loadedCert.validateCertificate()
    
} catch CardanoCoreError.ioError(let message) {
    print("File operation failed: \(message)")
} catch CardanoCoreError.deserializeError(let message) {
    print("Certificate parsing failed: \(message)")
} catch CardanoCoreError.invalidArgument(let message) {
    print("Certificate validation failed: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```


## See Also

- <doc:Transactions> - Including certificates in transactions
- <doc:Keys> - Generating keys for certificates
- <doc:Governance> - Advanced governance features
- <doc:StakePools> - Pool operation details
- <doc:Addresses> - Stake addresses and reward accounts

## Related Symbols

- ``Certificate``
- ``StakeRegistrationCertificate``
- ``StakeDelegationCertificate``
- ``PoolRegistrationCertificate``
- ``RegisterDRepCertificate``
- ``Credential``
- ``PoolParams``
