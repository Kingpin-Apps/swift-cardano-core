# Addresses

Create, parse, and manage Cardano addresses for different use cases.

## Overview

Cardano addresses encode payment and staking credentials using Blake2b-256 hashes of verification keys or script hashes. SwiftCardanoCore provides comprehensive support for all Cardano address types with full Bech32 encoding/decoding and network validation.

## Key Types & Concepts

### Address Types

- ``Address``: The main address type supporting all Cardano address formats
- **Base Address**: Contains both payment and stake credentials (most common)
- **Enterprise Address**: Contains only payment credentials (no staking)
- **Reward Address**: Stake reward withdrawal address
- **Pointer Address**: Uses stake pool delegation certificate pointer
- **Byron Address**: Legacy Byron-era addresses

### Network Types

- ``Network.mainnet``: Cardano mainnet (production)
- ``Network.testnet``: Preview/preprod testnet environments

### Credentials

- ``Credential.verificationKeyHash``: Address controlled by a cryptographic key
- ``Credential.scriptHash``: Address controlled by a script

## Step-by-Step Address Creation

### 1. Base Addresses (Payment + Stake)

```swift
import SwiftCardanoCore

// Generate key pairs
let paymentKeyPair = try PaymentKeyPair.generate()
let stakeKeyPair = try StakeKeyPair.generate()

// Create base address
let baseAddress = try Address(
    paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
    stakePart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .testnet
)

print("Base Address: \(baseAddress.toBech32())")

// Save to file (Cardano CLI compatible)
try baseAddress.save(to: "base.addr")
```

### 2. Enterprise Addresses (Payment Only)

```swift
// Enterprise address for exchanges or simple payments
let enterpriseAddress = try Address(
    paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
    network: .mainnet
)

print("Enterprise Address: \(enterpriseAddress.toBech32())")
```

### 3. Reward Addresses (Stake Only)

```swift
// Reward address for stake pool rewards
let rewardAddress = try Address(
    stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .mainnet
)

print("Reward Address: \(rewardAddress.toBech32())")
```

### 4. Script Addresses

```swift
// Address controlled by a script
let scriptHash = try nativeScript.scriptHash()
let scriptAddress = try Address(
    paymentPart: .scriptHash(scriptHash),
    stakePart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .testnet
)

print("Script Address: \(scriptAddress.toBech32())")
```

## Address Parsing and Validation

### Parse from Bech32 String

```swift
// Parse various address formats
let testnetAddr = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
let mainnetAddr = "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt6alqpggj7c6z"
let rewardAddr = "stake1u8pcjgmx7962w6hey5hhsd502araxp26kdtgagakhaqtq8sxy9w7g"

do {
    let parsedTestnet = try Address.fromBech32(testnetAddr)
    let parsedMainnet = try Address.fromBech32(mainnetAddr)
    let parsedReward = try Address.fromBech32(rewardAddr)
    
    print("Parsed testnet address: \(parsedTestnet.network)")
    print("Parsed mainnet address: \(parsedMainnet.network)")
    print("Parsed reward address: \(parsedReward.network)")
    
} catch {
    print("Address parsing failed: \(error)")
}
```


## Address File Operations

### Built-in Save and Load Methods

SwiftCardanoCore provides convenient built-in methods for saving addresses to and loading addresses from files in Cardano CLI-compatible format.

```swift
// Create an address
let paymentKeyPair = try PaymentKeyPair.generate()
let stakeKeyPair = try StakeKeyPair.generate()

let baseAddress = try Address(
    paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
    stakePart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .testnet
)

// Save address to file
try baseAddress.save(to: "payment.addr")
print("Address saved to payment.addr")

// Load address from file
let loadedAddress = try Address.load(from: "payment.addr")
print("Loaded address: \(loadedAddress.toBech32())")

// Verify they match
assert(baseAddress == loadedAddress)
```

### File Format Compatibility

The save and load methods are fully compatible with Cardano CLI address files:

```swift
// Save different address types
let enterpriseAddress = try Address(
    paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
    network: .mainnet
)

let rewardAddress = try Address(
    stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .mainnet
)

// Save to files
try baseAddress.save(to: "base.addr")
try enterpriseAddress.save(to: "enterprise.addr")
try rewardAddress.save(to: "stake.addr")

// These files can be used directly with cardano-cli commands
// For example: cardano-cli transaction build --tx-in-script-file script.json --tx-out $(cat base.addr)+1000000
```


## Error Handling

```swift
do {
    let address = try Address.fromBech32("invalid_address_string")
    try address.validateNetwork(.mainnet)
    try address.save(to: "address.addr")
    
} catch CardanoCoreError.invalidArgument(let message) {
    print("Invalid address parameter: \(message)")
} catch CardanoCoreError.deserializeError(let message) {
    print("Address parsing failed: \(message)")
} catch CardanoCoreError.encodingError(let message) {
    print("Address encoding failed: \(message)")
} catch {
    print("Address error: \(error)")
}
```


### Error Handling with File Operations

```swift
// Handle file operation errors
do {
// Save address
try baseAddress.save(to: "my-address.addr")

// Load address
let address = try Address.load(from: "my-address.addr")
print("Successfully loaded address: \(address.toBech32())")

} catch CardanoCoreError.ioError(let message) {
print("File operation failed: \(message)")
} catch CardanoCoreError.deserializeError(let message) {
print("Address parsing failed: \(message)")
} catch {
print("Unexpected error: \(error)")
}
```

## Testing and Validation

```swift
// Address round-trip testing
func testAddressRoundTrip() throws {
    let paymentKeyPair = try PaymentKeyPair.generate()
    let stakeKeyPair = try StakeKeyPair.generate()
    
    let originalAddress = try Address(
        paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
        stakePart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
        network: .testnet
    )
    
    // Test Bech32 round-trip
    let bech32String = originalAddress.toBech32()
    let parsedAddress = try Address.fromBech32(bech32String)
    assert(originalAddress == parsedAddress)
    
    // Test CBOR round-trip
    let cborData = try originalAddress.toCBORData()
    let deserializedAddress = try Address.fromCBOR(data: cborData)
    assert(originalAddress == deserializedAddress)
}

// Address format validation
func validateAddressFormat(_ addressString: String) -> Bool {
    do {
        let address = try Address.fromBech32(addressString)
        return true
    } catch {
        return false
    }
}

// Test known address formats
let validAddresses = [
    "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
    "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt6alqpggj7c6z",
    "stake1u8pcjgmx7962w6hey5hhsd502araxp26kdtgagakhaqtq8sxy9w7g"
]

for addressString in validAddresses {
    assert(validateAddressFormat(addressString))
}
```

## See Also

- <doc:Keys> - Generating keys for addresses
- <doc:Transactions> - Using addresses in transactions
- <doc:Scripts> - Script-based addresses
- <doc:Certificates> - Reward addresses and staking

## Related Symbols

- ``Address``
- ``Network``
- ``Credential``
- ``VerificationKeyHash``
- ``ScriptHash``
- ``PaymentKeyPair``
- ``StakeKeyPair``
