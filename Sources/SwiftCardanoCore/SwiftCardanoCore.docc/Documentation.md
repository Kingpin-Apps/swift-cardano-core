# ``SwiftCardanoCore``

A Swift implementation of Cardano Data Types with CBOR (and JSON) serialization.

## Overview

SwiftCardanoCore is a Swift implementation of Cardano Data Types with CBOR (and JSON) serialization.
It is designed to be used as a dependency in other Cardano related Swift projects.

### Addresses

The `Address` module provides types and functions for working with Cardano addresses.

```swift
import SwiftCardanoCore

let address = try Address(from: "addr1qy3m3w8...")
```

### Certificate

The `Certificate` module provides types and functions for working with Cardano certificates.

```swift
import SwiftCardanoCore

let sk = try StakeSigningKey.generate()
let vk: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(sk)

let stakeCredential = StakeCredential(credential: .verificationKeyHash(try! vk.hash()))
let stakeRegistration = StakeRegistration(stakeCredential: stakeCredential)
let certificate = try Certificate.stakeRegistration(stakeRegistration)
```


## Topics

- <!--@START_MENU_TOKEN@-->``Symbol``<!--@END_MENU_TOKEN@-->
