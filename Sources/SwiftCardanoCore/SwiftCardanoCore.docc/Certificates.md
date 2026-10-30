# Certificates

Create and manage Cardano certificates for staking, governance, and pool operations.

## Overview

Certificates are special transaction components that enable staking operations, pool management, and governance participation on the Cardano blockchain. SwiftCardanoCore provides comprehensive support for all certificate types across different Cardano eras.

## Key Types & Concepts

### Certificate Types

- ``Certificate``: The main certificate enum containing all certificate variants
- ``Register`` & ``Unregister``: Register or unregister a stake address, stating the deposit (Conway)
- ``StakeRegistration`` & ``StakeDeregistration``: The Shelley-era forms, which leave the deposit to the protocol parameters
- ``StakeDelegation``: Delegate stake to a pool
- ``StakeRegisterDelegate``: Register a stake address and delegate it in one certificate
- ``PoolRegistration``: Register a new stake pool
- ``PoolRetirement``: Retire an existing stake pool

### Governance Certificates

- ``RegisterDRep``: Register as a Delegated Representative
- ``UnregisterDRep``: Unregister a DRep
- ``UpdateDRep``: Update DRep information
- ``VoteDelegate``: Delegate voting power

### Committee Certificates

- ``AuthCommitteeHot``: Authorize committee hot key
- ``ResignCommitteeCold``: Resign from committee

### Credentials

Certificates name their subject by a credential: a ``StakeCredential``, a
``DRepCredential`` or a committee credential, each wrapping a
``CredentialType`` (`.verificationKeyHash` or `.scriptHash`). A vote
delegation names a ``DRep``.

## Step-by-Step Certificate Creation

These examples are compiled and run by the package's tests
(`CertificatesGuideExamplesTests`), so they stay true to the API. Later
examples use the `stakeCredential`, `poolKeyHash`, `poolKeyPair` and
`drepKeyPair` of earlier ones, and the transaction example assumes a
`txInput` and a `txOutput` of your own.

### 1. Stake Registration

```swift
import SwiftCardanoCore

// Generate stake keys
let stakeKeyPair = try StakeKeyPair.generate()

// Create stake credential
let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()))

// Create registration certificate (Conway: the certificate states the deposit)
let stakeRegistration = try Register(
    stakeCredential: stakeCredential,
    coin: Coin(2_000_000) // Registration deposit (2 ADA)
)

let certificate = Certificate.register(stakeRegistration)

// The Shelley-era certificate leaves the deposit to the protocol parameters
let legacyRegistration = Certificate.stakeRegistration(try StakeRegistration(stakeCredential: stakeCredential))
```

### 2. Stake Delegation

```swift
// Pool ID to delegate to
let poolOperator = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")

// Create delegation certificate
let stakeDelegation = try StakeDelegation(
    stakeCredential: stakeCredential,
    poolKeyHash: poolOperator.poolKeyHash
)

let delegationCert = Certificate.stakeDelegation(stakeDelegation)
```

### 3. Combined Registration and Delegation

```swift
// Modern approach: register and delegate in one certificate
let stakeRegisterDelegate = try StakeRegisterDelegate(
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

// Pool metadata: where the metadata file is, and its hash
let poolMetadata = try PoolMetadata(
    url: try Url("https://example.com/pool-metadata.json"),
    poolMetadataHash: PoolMetadataHash(payload: Data(repeating: 0x01, count: 32))
)

// The reward account: the bytes of the operator's stake address
let rewardAddress = try Address(
    stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .mainnet
)

// Pool parameters
let poolParams = PoolParams(
    poolOperator: try poolKeyPair.verificationKey.poolKeyHash(),
    vrfKeyHash: try vrfKeyPair.verificationKey.hash(),
    pledge: Coin(100_000_000_000), // 100,000 ADA
    cost: Coin(340_000_000), // 340 ADA minimum
    margin: UnitInterval(numerator: 3, denominator: 100), // 3% margin
    rewardAccount: RewardAccountHash(payload: rewardAddress.toBytes()),
    poolOwners: .list([try stakeKeyPair.verificationKey.hash()]),
    relays: [], // Add relay information as needed
    poolMetadata: poolMetadata
)

// Create pool registration certificate
let poolRegistration = try PoolRegistration(poolParams: poolParams)
let poolRegCert = Certificate.poolRegistration(poolRegistration)
```

### Pool Retirement

```swift
// Retire pool at specific epoch
let poolRetirement = try PoolRetirement(
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
let drepRegistration = try RegisterDRep(
    drepCredential: DRepCredential(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash())),
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
let voteDelegation = try VoteDelegate(
    stakeCredential: stakeCredential,
    drep: DRep(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash()))
)

let voteDelegationCert = Certificate.voteDelegate(voteDelegation)

// Alternative: delegate to always abstain
let alwaysAbstainDelegation = try VoteDelegate(
    stakeCredential: stakeCredential,
    drep: DRep(credential: .alwaysAbstain)
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

// Serialize a list of certificates
let certificatesData = try ListOrNonEmptyOrderedSet.list(certificates).toCBORData()
```

### Save and Load Methods

Each certificate type, such as ``Register`` or ``StakeDelegation``, conforms to the ``CertificateSerializable`` protocol, providing convenient methods for saving to and loading from JSON text-envelope files in Cardano CLI-compatible format. The ``Certificate`` enum that wraps them does not.

```swift
// Create a certificate
let stakeKeyPair = try StakeKeyPair.generate()
let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()))
let stakeRegistration = try Register(
    stakeCredential: stakeCredential,
    coin: Coin(2_000_000)
)

// Save certificate to file
try stakeRegistration.save(to: "stake-registration.cert")
print("Certificate saved to stake-registration.cert")

// Load certificate from file
let loadedCertificate = try Register.load(from: "stake-registration.cert")
print("Certificate loaded successfully")

// Verify they match
assert(stakeRegistration == loadedCertificate)
```

### File Format Compatibility

The save and load methods are fully compatible with Cardano CLI certificate files:

```swift
// Save different certificate types
let poolOperator = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")
let delegationCert = try StakeDelegation(
    stakeCredential: stakeCredential,
    poolKeyHash: poolOperator.poolKeyHash
)

let drepKeyPair = try DRepKeyPair.generate()
let drepCert = try RegisterDRep(
    drepCredential: DRepCredential(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash())),
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

`save(to:)` throws `CardanoCoreError.ioError` when the file already exists
(pass `overwrite: true` to replace it), and `load(from:)` throws
`CardanoCoreError.deserializeError` when the file holds another kind of
certificate. A missing file throws Foundation's file-reading error.

```swift
do {
    // Save certificate
    try stakeRegistration.save(to: "my-certificate.cert")

    // Load certificate
    let loadedCert = try Register.load(from: "my-certificate.cert")
    print("Certificate loaded successfully: \(loadedCert.description)")

} catch CardanoCoreError.ioError(let message) {
    print("File operation failed: \(message ?? "")")
} catch CardanoCoreError.deserializeError(let message) {
    print("Certificate parsing failed: \(message ?? "")")
} catch {
    print("Certificate file operation failed: \(error)")
}
```


## See Also

- <doc:Transactions> - Including certificates in transactions
- <doc:Keys> - Generating keys for certificates
- <doc:StakePools> - Pool operation details
- <doc:Addresses> - Stake addresses and reward accounts

## Related Symbols

- ``Certificate``
- ``Register``
- ``StakeDelegation``
- ``PoolRegistration``
- ``RegisterDRep``
- ``StakeCredential``
- ``PoolParams``
- ``CardanoCoreError``
