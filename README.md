![GitHub Workflow Status](https://github.com/Kingpin-Apps/swift-cardano-core/actions/workflows/swift.yml/badge.svg)

# SwiftCardanoCore - Swift implementation of Cardano Data Types

SwiftCardanoCore is a Swift implementation of Cardano Data Types with CBOR (and JSON) serialization.

## Usage
To add SwiftCardanoCore as dependency to your Xcode project, select `File` > `Swift Packages` > `Add Package Dependency`, enter its repository URL: `https://github.com/Kingpin-Apps/swift-cardano-core.git` and import `SwiftCardanoCore`.

Then, to use it in your source code, add:

```swift
import SwiftCardanoCore

let paymentSKey = try PaymentSigningKey.generate()
paymentSKey.save(to: "payment.skey")

let paymentVKey: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(sk)
paymentVKey.save(to: "payment.vkey")

let stakeSKey = try StakeSigningKey.generate()
stakeSKey.save(to: "stake.skey")

let stakeVKey: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(sk)
stakeVKey.save(to: "stake.vkey")

let address = try Address(paymentPart: .verificationKeyHash(try paymentVKey.hash()), stakePart: .verificationKeyHash(try stakeVKey.hash()), network: .testnet)
address.save(to: "address.addr")
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
