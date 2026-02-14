## 0.2.27 (2026-02-14)

### Fix

- improve VRF key
- add OperationalCertificateIssueCounter and tests

## 0.2.26 (2026-02-13)

### Fix

- make hash functions public

## 0.2.25 (2026-02-13)

### Fix

- add Block models and tests

## 0.2.24 (2026-02-12)

### Fix

- add hash function

## 0.2.23 (2025-11-10)

### Fix

- add era from epoch

## 0.2.22 (2025-11-10)

### Fix

- handle loading and hashing better

## 0.2.21 (2025-11-03)

### Fix

- fix save in JSONLoadable

## 0.2.20 (2025-11-03)

### Fix

- add overwrite to save

## 0.2.19 (2025-11-02)

### Fix

- add active and active epoch

## 0.2.18 (2025-11-02)

### Fix

- add TextEnvelopable to TXBody

## 0.2.17 (2025-11-01)

### Fix

- handle to JSON and to TextEnvelope better

## 0.2.16 (2025-10-29)

### Fix

- handle plutus types and redeemers serializable

## 0.2.15 (2025-10-28)

### Fix

- add pretty printing to various types
- add Serializable and JSONDescribable for json printing

## 0.2.14 (2025-10-26)

### Fix

- handle governance credentials and CIP129 ids

## 0.2.13 (2025-10-23)

### Fix

- use bigEndian for IP encoding

## 0.2.12 (2025-10-23)

### Fix

- handle primitive string

## 0.2.11 (2025-10-23)

### Fix

- use int for value

## 0.2.10 (2025-10-23)

### Fix

- improve handling of PutusData bytes

## 0.2.9 (2025-10-22)

### Fix

- make funcs public

## 0.2.8 (2025-10-21)

### Fix

- refactor PoolId to PoolOperator and handle ids

## 0.2.7 (2025-10-20)

### Fix

- remove snake case keys

## 0.2.6 (2025-10-20)

### Fix

- add ChainTip

## 0.2.5 (2025-10-19)

### Fix

- refactor to use Primitives instead of AnyValue and use PlutusData

## 0.2.4 (2025-10-16)

### Fix

- handle DRep Id parsing and add stake address info tests

## 0.2.3 (2025-10-16)

### Fix

- add init from DRepID hex data

## 0.2.2 (2025-10-15)

### Fix

- add DRep init from bech32 id with CIP129 support

## 0.2.1 (2025-10-15)

### Fix

- add Network and refactorNetworkId

## 0.2.0 (2025-10-13)

### Feat

- add VRF functionality

### Fix

- improve payload decoding/encoding

## 0.1.34 (2025-10-06)

### Fix

- add encoding type for depreciation warning
- handle AnyValue conversion better for Linux compatibility
- add equality between IndefiniteList and List
- add swift-crypto for cross platform
- add isSubCLassOf
- use new IP Address
- add IPAddress
- make ByteString Hashable
- add description and from era

## 0.1.33 (2025-09-29)

### Fix

- use swift-mnemonic and other improvementsp

## 0.1.32 (2025-09-06)

### Fix

- fixes to work with builder

## 0.1.31 (2025-08-31)

### Fix

- add convenience methods

## 0.1.30 (2025-08-31)

### Fix

- minor fixes since refactor

### Refactor

- use toPrimitive and init from primitive for encoding

## 0.1.29 (2025-08-24)

### Fix

- update cryptoswift

## 0.1.28 (2025-08-21)

### Fix

- enhance Value initialization to support multiple primitive types

### Refactor

- handle optional datumHash initialization in TransactionOutput
- improve Value initialization and MultiAsset comparisons
- initialize logging setup once

## 0.1.27 (2025-05-04)

### Refactor

- add to and from primitives

## 0.1.26 (2025-04-25)

### Fix

- lock PotentCodables version

## 0.1.25 (2025-04-25)

### Fix

- improve Value and MultiAssets comparing

## 0.1.24 (2025-04-24)

### Fix

- handle Reedemers and Datums

## 0.1.23 (2025-04-24)

### Fix

- init cost models from array of ints

## 0.1.22 (2025-04-24)

### Fix

- fix costmodels and add more reedemer tests

## 0.1.21 (2025-04-23)

### Fix

- use T in ReedemerValue

## 0.1.20 (2025-04-23)

### Fix

- use generic type for Reedemer data

## 0.1.19 (2025-04-10)

### Fix

- handle plutus data serialization

## 0.1.18 (2025-03-18)

### Fix

- bug fixes for txbuilder

## 0.1.17 (2025-03-17)

### Fix

- use CBORSerializable and other improvements

## 0.1.16 (2025-03-15)

### Fix

- lock PotentCodables to revision

## 0.1.15 (2025-03-15)

### Fix

- handle preview

## 0.1.14 (2025-03-15)

### Fix

- improve Nativescripts and fix test
- minor fixes

## 0.1.13 (2025-03-13)

### Fix

- add CBORSerializable protocol and improve Transaction

## 0.1.12 (2025-03-12)

### Fix

- use proper hashing

## 0.1.11 (2025-03-12)

### Fix

- add payload check and tests
- handle extended keys and add tests

## 0.1.10 (2025-03-07)

### Fix

- make more public

## 0.1.9 (2025-03-07)

### Fix

- make Extensions public

## 0.1.8 (2025-03-07)

### Fix

- make Types public

## 0.1.7 (2025-03-07)

### Fix

- make funtions public

## 0.1.6 (2025-03-07)

### Fix

- make public

## 0.1.5 (2025-03-07)

### Fix

- add public modifier

## 0.1.4 (2025-03-06)

### Fix

- add enum type for SigningKey and VerificationKey

## 0.1.3 (2025-03-06)

### Fix

- make func public

## 0.1.2 (2025-03-06)

### Fix

- add to Readme

## 0.1.1 (2025-03-03)

### Fix

- make public
