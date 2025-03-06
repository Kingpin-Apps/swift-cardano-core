# Keys

The `Keys` module provides types and functions for working with Cardano keys.

## Overview

In Cardano, the two primary types of keys are payment keys and stake keys, both based on the Ed25519 cryptographic algorithm.

Payment keys are primarily responsible for authorizing transactions involving fund transfers, whereas stake keys are used for staking-related operations, such as registering stake addresses and delegating stake.

`SwiftCardanoCore` offers APIs to generate, save, and load various types of keys.

New keys can be created using the generate method, while their corresponding public (verification) keys can be derived with the `fromSigningKey` method.

### Payment Keys

```swift
import SwiftCardanoCore

let sk = try PaymentSigningKey.generate()
let vk: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(sk)
```

```swift
import SwiftCardanoCore

let paymentKeyPair = PaymentKeyPair.generate()

let sk = paymentKeyPair.signingKey
let vk = paymentKeyPair.verificationKey
```

### Stake Keys

```swift
import SwiftCardanoCore

let sk = try StakeSigningKey.generate()
let vk: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(sk)
```

```swift
import SwiftCardanoCore

let stakeKeyPair = StakeKeyPair.generate()

let sk = stakeKeyPair.signingKey
let vk = stakeKeyPair.verificationKey
```
