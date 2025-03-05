# Address

The `Address` module provides types and functions for working with Cardano addresses.

## Overview

In Cardano, the two primary types of keys are payment keys and stake keys, both based on the Ed25519 cryptographic algorithm.

Payment keys are primarily responsible for authorizing transactions involving fund transfers, whereas stake keys are used for staking-related operations, such as registering stake addresses and delegating stake.

`SwiftCardanoCore` offers APIs to generate, save, and load various types of keys.

New keys can be created using the generate method, while their corresponding public (verification) keys can be derived with the `fromSigningKey` method.

### Payment and Stake Keys

```swift
import SwiftCardanoCore

let sk = try PaymentSigningKey.generate()
let vk: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(sk)
```

