# ``SwiftCardanoCore``

A comprehensive Swift library for working with Cardano blockchain data types, transactions, and cryptographic operations.

## Overview

SwiftCardanoCore provides a complete Swift implementation of Cardano's data structures with full CBOR and JSON serialization support. This library enables Swift developers to build Cardano applications, wallets, and tools with native iOS, macOS, tvOS, and watchOS integration.

### Key Features

- **Complete Cardano Data Types**: Full implementation of addresses, transactions, certificates, metadata, and more
- **Cryptographic Operations**: Ed25519 key generation, signing, and verification
- **CBOR Serialization**: Native support for Cardano's CBOR encoding/decoding
- **Multi-Era Support**: Compatible with Byron, Shelley, Allegra, Mary, Alonzo, Babbage, and Conway eras
- **Native Asset Support**: Work with ADA and native tokens seamlessly
- **Smart Contract Integration**: Support for Plutus scripts and native scripts
- **Governance Features**: DRep registration, voting procedures, and governance actions

### Quick Start

```swift
import SwiftCardanoCore

// Generate cryptographic keys
let paymentKeyPair = try PaymentKeyPair.generate()
let stakeKeyPair = try StakeKeyPair.generate()

// Create a Cardano address
let address = try Address(
    paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
    stakePart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
    network: .testnet
)

print("Generated address: \(address.toBech32())")
```

### Supported Platforms

- **iOS**: 15.0+
- **macOS**: 12.0+
- **tvOS**: 15.0+
- **watchOS**: 8.0+
- **Swift**: 6.2+
- **Linux**

## Topics

### Core Concepts

- <doc:Keys>
- <doc:Addresses>
- <doc:Transactions>
- <doc:Certificates>

### Advanced Features

- <doc:Assets>
- <doc:Scripts>
- <doc:Plutus>
- <doc:Governance>
- <doc:Metadata>

### Configuration & Utilities

- <doc:Serialization>
- <doc:Configuration>
- <doc:StakePools>

### Error Handling

- ``CardanoCoreError``
