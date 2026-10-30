# Migrating from 0.9

Update code written against SwiftCardanoCore 0.9 for this release.

## Overview

This release makes the library read, write and hash every value as the
Cardano ledger does, and it changes the public API to do so. Most changes
are mechanical: a field now has the ledger's exact type, or an initialiser that
can be handed invalid input now throws. The compiler finds every one of them.
A few change behaviour without a compile error; they are listed under
<doc:#Changes-the-compiler-does-not-catch>.

## Exact types for ledger values

Values the ledger holds as integers or exact rationals are no longer `Double`,
`Int` or `String`:

- Protocol parameters, genesis files and voting thresholds hold rationals as
  ``UnitInterval`` or ``NonNegativeInterval`` instead of `Double`, and
  `Threshold` is replaced by ``UnitInterval``.
- Amounts are ``Coin`` (`UInt64`), and token quantities and ``Value/coin``
  are `BigInt`, so a token amount above `Int64.max` — which the ledger allows —
  is held exactly. ``Asset`` maps an ``AssetName`` to a `BigInt`.
- Counts, sizes, slots and indices have the ledger's width: `UInt16`,
  `UInt32` or `UInt64` instead of `Int`. ``PointerAddress`` takes a `UInt32`
  slot and `UInt16` indices.
- `ExecutionPrices` and `PriceRatio` are replaced by ``ExecutionUnitPrices``.

The table at the end lists every property whose type changed.

## Initialisers that check their input

Certificates, pool registrations and retirements, governance proposals, relay
host names and committee authorisations check what they are given — sizes,
ranges, a DNS name's length — and throw ``CardanoCoreError`` instead of
building a value the ledger would reject. Add `try` where the compiler asks.
`hash()` on a block, a header and a transaction body throws too, as encoding
can fail.

## Data of any depth

Plutus data, transaction metadata and native scripts can nest as deep as a
transaction allows, and are read, compared, hashed and freed without
recursion. Their nested cases hold new collection types:

- ``PlutusData/array(_:)-enum.case`` holds a ``NestedList`` and ``PlutusData/map(_:)``
  a ``MapPairs``. Build them from Swift arrays with
  `PlutusData.array([...])` and `MapPairs([(key, value)])`; a ``NestedList``
  is a `RandomAccessCollection`, so most reading code is unchanged.
- ``TransactionMetadatum/list(_:)-enum.case`` holds a ``NestedList`` and
  ``TransactionMetadatum/map(_:)`` a ``MapPairs``.
- A pattern that binds the payload as `[PlutusData]` must bind the
  ``NestedList`` instead, or convert with `Array(list)`.

## Native scripts

A native script read from CBOR keeps the bytes it was read from, in
`originalCBOR`, and its hash is taken over them, as the ledger's is. The
script structs ``ScriptAll``, ``ScriptAny``, ``ScriptNofK`` and the others
gain that property; `==` and hashing ignore it. A script built in Swift is
written in its canonical form, as before.

## Keys

- `fromSigningKey(_:)` returns `Self`: write
  `try PaymentVerificationKey.fromSigningKey(signingKey)` without a type
  annotation.
- `fromHDWallet(_:)` returns the key type it is called on, not
  `any ExtendedSigningKeyProtocol`; drop any `as!` cast after it. The key is
  labelled with its own type, so a stake key is no longer labelled as a
  payment key.
- Extended signing keys have `generate()`, and verification keys
  `verify(signature:data:)`.
- `load(from:)` refuses a file holding another type of key and throws
  ``CardanoCoreError/invalidKeyTypeError(_:)``. Load an untyped file with
  ``SigningKey`` or ``VerificationKey``.

## Errors

``CardanoCoreError`` is public, so you can match its cases. Loading any file
that cannot be read — missing, unreadable, not UTF-8 — throws
``CardanoCoreError/ioError(_:)`` instead of a Foundation error.

## Protocol parameters

``ProtocolParameters`` encode to the ledger's 31-element list, the form a
node's local state query returns, instead of a map.

## Changes the compiler does not catch

- **JSON writes bytes as hex**, as cardano-cli does, instead of base64, and
  reads either. Several types have a new JSON form so that every type reads
  its JSON back: relays, voting procedures (a list of voters and their votes),
  redeemer maps (`{"map": [...]}`), sets and lists written as tagged or
  indefinite-length (`{"set": [...]}` and similar), governance action ids,
  unit intervals, bootstrap witnesses, credentials, operational certificates
  and pool metadata. A type with no JSON form of its own is written as its
  CBOR shape, or as CBOR hex. JSON keeps values, not bytes: move anything
  signed as CBOR or a text envelope.
- **JSON numbers** that are not negative are read as `.uint`, as CBOR reads
  them, and JSON booleans as `.bool`.
- **Operational certificates** compare their cold verification key in `==`,
  so a certificate read from a block (no cold key) differs from the same one
  read from a text envelope. `issue(...)` throws when the issue counter
  belongs to another cold key.
- **`AnyValue`** is reachable through `import SwiftCardanoCore`.

## Byron

Byron blocks decode in full. The stored `absoluteSlot` property, which came
from the network framing rather than the block, is replaced by a method that
computes it from the block's epoch and slot: `absoluteSlot(epochLength:)`,
whose default is mainnet's epoch length. Their initialisers no longer take it.

## Changed property types

**``AlonzoCostModels``**

| Property | Was | Now |
|---|---|---|
| `plutusV1` | `[String : Int]` | `[Int64]` |

**``AlonzoGenesis``**

| Property | Was | Now |
|---|---|---|
| `collateralPercentage` | `Int` | `UInt16` |
| `executionPrices` | `ExecutionPrices` | `ExecutionUnitPrices` |
| `lovelacePerUTxOWord` | `Int64` | `Coin` |
| `maxCollateralInputs` | `Int` | `UInt16` |
| `maxValueSize` | `Int` | `UInt32` |

**``AlonzoGenesisExUnits``**

| Property | Was | Now |
|---|---|---|
| `exUnitsMem` | `Int` | `UInt64` |
| `exUnitsSteps` | `Int` | `UInt64` |

**``BlockVersionData``**

| Property | Was | Now |
|---|---|---|
| `heavyDelThd` | `String` | `LovelacePortion` |
| `maxBlockSize` | `String` | `UInt64` |
| `maxHeaderSize` | `String` | `UInt64` |
| `maxProposalSize` | `String` | `UInt64` |
| `maxTxSize` | `String` | `UInt64` |
| `mpcThd` | `String` | `LovelacePortion` |
| `scriptVersion` | `Int` | `UInt16` |
| `slotDuration` | `String` | `UInt64` |
| `unlockStakeEpoch` | `String` | `EpochNumber` |
| `updateImplicit` | `String` | `UInt64` |
| `updateProposalThd` | `String` | `LovelacePortion` |
| `updateVoteThd` | `String` | `LovelacePortion` |

**``ByronBlockHeader``**

| Property | Was | Now |
|---|---|---|
| `BFTHead.bodyProof` | `Data` | `ByronBlockHeader.BlockProof` |
| `BFTHead.prevBlock` | `Data?` | `Data` |
| `EBBHead.prevBlock` | `Data?` | `Data` |
| `prevBlock` | `Data?` | `Data` |

**``ByronGenesis``**

| Property | Was | Now |
|---|---|---|
| `avvmDistr` | `[String : String]` | `[String : Coin]` |
| `bootStakeholders` | `[String : Int]` | `[String : UInt16]` |
| `nonAvvmBalances` | `[String : String]` | `[String : Coin]` |

**``Committee``**

| Property | Was | Now |
|---|---|---|
| `members` | `[String : Int]` | `[String : EpochNumber]` |
| `threshold` | `Threshold` | `UnitInterval` |

**``ConwayGenesis``**

| Property | Was | Now |
|---|---|---|
| `committeeMaxTermLength` | `Int` | `EpochInterval` |
| `committeeMinSize` | `Int` | `UInt16` |
| `dRepActivity` | `Int` | `EpochInterval` |
| `govActionLifetime` | `Int` | `EpochInterval` |
| `minFeeRefScriptCostPerByte` | `Int64` | `NonNegativeInterval` |
| `plutusV3CostModel` | `[Int]` | `[Int64]` |

**``ConwayGenesisConstitution``**

| Property | Was | Now |
|---|---|---|
| `script` | `String` | `String?` |

**``ConwayGenesisDRepVotingThresholds``**

| Property | Was | Now |
|---|---|---|
| `committeeNoConfidence` | `Double` | `UnitInterval` |
| `committeeNormal` | `Double` | `UnitInterval` |
| `hardForkInitiation` | `Double` | `UnitInterval` |
| `motionNoConfidence` | `Double` | `UnitInterval` |
| `ppEconomicGroup` | `Double` | `UnitInterval` |
| `ppGovGroup` | `Double` | `UnitInterval` |
| `ppNetworkGroup` | `Double` | `UnitInterval` |
| `ppTechnicalGroup` | `Double` | `UnitInterval` |
| `treasuryWithdrawal` | `Double` | `UnitInterval` |
| `updateToConstitution` | `Double` | `UnitInterval` |

**``ConwayGenesisPoolVotingThresholds``**

| Property | Was | Now |
|---|---|---|
| `committeeNoConfidence` | `Double` | `UnitInterval` |
| `committeeNormal` | `Double` | `UnitInterval` |
| `hardForkInitiation` | `Double` | `UnitInterval` |
| `motionNoConfidence` | `Double` | `UnitInterval` |
| `ppSecurityGroup` | `Double` | `UnitInterval` |

**``DRepVotingThresholds``**

| Property | Was | Now |
|---|---|---|
| `committeeNoConfidence` | `Double` | `UnitInterval` |
| `committeeNormal` | `Double` | `UnitInterval` |
| `hardForkInitiation` | `Double` | `UnitInterval` |
| `motionNoConfidence` | `Double` | `UnitInterval` |
| `ppEconomicGroup` | `Double` | `UnitInterval` |
| `ppGovGroup` | `Double` | `UnitInterval` |
| `ppNetworkGroup` | `Double` | `UnitInterval` |
| `ppTechnicalGroup` | `Double` | `UnitInterval` |
| `treasuryWithdrawal` | `Double` | `UnitInterval` |
| `updateToConstitution` | `Double` | `UnitInterval` |

**``ExecutionUnitPrices``**

| Property | Was | Now |
|---|---|---|
| `priceMemory` | `Double` | `NonNegativeInterval` |
| `priceSteps` | `Double` | `NonNegativeInterval` |

**``GenesisParameters``**

| Property | Was | Now |
|---|---|---|
| `activeSlotsCoefficient` | `Double?` | `UnitInterval?` |
| `epochLength` | `Int?` | `UInt64?` |
| `maxKesEvolutions` | `Int?` | `UInt64?` |
| `maxLovelaceSupply` | `Int?` | `UInt64?` |
| `networkMagic` | `Int?` | `UInt32?` |
| `securityParam` | `Int?` | `UInt64?` |
| `slotLength` | `Int?` | `Decimal?` |
| `slotsPerKesPeriod` | `Int?` | `UInt64?` |
| `updateQuorum` | `Int?` | `UInt64?` |

**``HeavyDelegation``**

| Property | Was | Now |
|---|---|---|
| `omega` | `Int` | `EpochNumber` |

**``MinReferenceScriptsSize``**

| Property | Was | Now |
|---|---|---|
| `base` | `Double?` | `NonNegativeInterval?` |
| `multiplier` | `Double?` | `NonNegativeInterval?` |
| `range` | `Double?` | `UInt32?` |

**``MoveInstantaneousReward``**

| Property | Was | Now |
|---|---|---|
| `rewards` | `[String : DeltaCoin]?` | `OrderedDictionary<StakeCredential, DeltaCoin>?` |

**``NodeConfig``**

| Property | Was | Now |
|---|---|---|
| `lastKnownBlockVersionAlt` | `Int?` | `UInt8?` |
| `lastKnownBlockVersionMajor` | `Int?` | `UInt16?` |
| `lastKnownBlockVersionMinor` | `Int?` | `UInt16?` |
| `maxKnownMajorProtocolVersion` | `Int?` | `UInt64?` |

**``PoolParams``**

| Property | Was | Now |
|---|---|---|
| `cost` | `Int` | `Coin` |
| `pledge` | `Int` | `Coin` |

**``PoolVotingThresholds``**

| Property | Was | Now |
|---|---|---|
| `committeeNoConfidence` | `UnitInterval?` | `UnitInterval` |
| `committeeNormal` | `UnitInterval?` | `UnitInterval` |
| `hardForkInitiation` | `UnitInterval?` | `UnitInterval` |
| `motionNoConfidence` | `UnitInterval?` | `UnitInterval` |
| `ppSecurityGroup` | `UnitInterval?` | `UnitInterval` |

**``ProtocolConsts``**

| Property | Was | Now |
|---|---|---|
| `k` | `Int` | `UInt64` |
| `protocolMagic` | `Int` | `UInt32` |
| `vssMaxTTL` | `Int?` | `UInt32?` |
| `vssMinTTL` | `Int?` | `UInt32?` |

**``ProtocolParamUpdate``**

| Property | Was | Now |
|---|---|---|
| `extraEntropy` | `UInt32?` | `Nonce?` |

**``ProtocolParameters``**

| Property | Was | Now |
|---|---|---|
| `coinsPerUtxoWord` | `Int64` | `Coin` |
| `collateralPercentage` | `Int64` | `UInt16` |
| `committeeMaxTermLength` | `Int64` | `EpochInterval` |
| `committeeMinSize` | `Int64` | `UInt16` |
| `dRepActivity` | `Int64` | `EpochInterval` |
| `dRepDeposit` | `Int64` | `Coin` |
| `govActionDeposit` | `Int64` | `Coin` |
| `govActionLifetime` | `Int64` | `EpochInterval` |
| `maxBlockBodySize` | `Int64` | `UInt32` |
| `maxBlockHeaderSize` | `Int64` | `UInt16` |
| `maxCollateralInputs` | `Int64` | `UInt16` |
| `maxTxSize` | `Int64` | `UInt32` |
| `maxValueSize` | `Int64` | `UInt32` |
| `minFeeRefScriptCostPerByte` | `Int64?` | `NonNegativeInterval?` |
| `minPoolCost` | `Int64` | `Coin` |
| `monetaryExpansion` | `Double` | `UnitInterval` |
| `poolPledgeInfluence` | `Double` | `NonNegativeInterval` |
| `poolRetireMaxEpoch` | `Int64` | `EpochInterval` |
| `stakeAddressDeposit` | `Int64` | `Coin` |
| `stakePoolDeposit` | `Int64` | `Coin` |
| `stakePoolTargetNum` | `Int64` | `UInt16` |
| `treasuryCut` | `Double` | `UnitInterval` |
| `txFeeFixed` | `Int64` | `Coin` |
| `txFeePerByte` | `Int64` | `Coin` |
| `utxoCostPerByte` | `Int64` | `Coin` |

**``ProtocolParametersExecutionUnits``**

| Property | Was | Now |
|---|---|---|
| `memory` | `Int64` | `UInt64` |
| `steps` | `Int64` | `UInt64` |

**``ProtocolParametersPoolVotingThresholds``**

| Property | Was | Now |
|---|---|---|
| `committeeNoConfidence` | `Double` | `UnitInterval` |
| `committeeNormal` | `Double` | `UnitInterval` |
| `hardForkInitiation` | `Double` | `UnitInterval` |
| `motionNoConfidence` | `Double` | `UnitInterval` |
| `ppSecurityGroup` | `Double` | `UnitInterval` |

**``ProtocolParametersProtocolVersion``**

| Property | Was | Now |
|---|---|---|
| `major` | `Int` | `UInt32` |
| `minor` | `Int` | `UInt32` |

**``ProtocolParams``**

| Property | Was | Now |
|---|---|---|
| `ProtocolVersion.major` | `Int` | `UInt32` |
| `ProtocolVersion.minor` | `Int` | `UInt32` |
| `a0` | `Double` | `NonNegativeInterval` |
| `decentralisationParam` | `Double` | `UnitInterval` |
| `eMax` | `Int` | `EpochInterval` |
| `maxBlockHeaderSize` | `UInt32` | `UInt16` |
| `minFeeA` | `UInt32` | `Coin` |
| `minFeeB` | `UInt32` | `Coin` |
| `nOpt` | `Int` | `UInt16` |
| `rho` | `Double` | `UnitInterval` |
| `tau` | `Double` | `UnitInterval` |

**``Rotation``**

| Property | Was | Now |
|---|---|---|
| `rpKeepFilesNum` | `Int` | `UInt64` |
| `rpLogLimitBytes` | `Int` | `UInt64` |
| `rpMaxAgeHours` | `Int` | `UInt64` |

**``ShelleyGenesis``**

| Property | Was | Now |
|---|---|---|
| `activeSlotsCoeff` | `Double` | `UnitInterval` |
| `epochLength` | `UInt32` | `UInt64` |
| `initialFunds` | `[String : Int]` | `OrderedDictionary<String, Coin>` |
| `maxKESEvolutions` | `UInt32` | `UInt64` |
| `securityParam` | `UInt32` | `UInt64` |
| `slotLength` | `UInt32` | `Decimal` |
| `slotsPerKESPeriod` | `UInt32` | `UInt64` |
| `updateQuorum` | `Int` | `UInt64` |

**``SoftforkRule``**

| Property | Was | Now |
|---|---|---|
| `initThd` | `String` | `LovelacePortion` |
| `minThd` | `String` | `LovelacePortion` |
| `thdDecrement` | `String` | `LovelacePortion` |

**``TxFeePolicy``**

| Property | Was | Now |
|---|---|---|
| `multiplier` | `String` | `UInt64` |
| `summand` | `String` | `Coin` |

**``VSSCert``**

| Property | Was | Now |
|---|---|---|
| `expiryEpoch` | `Int` | `EpochNumber` |
