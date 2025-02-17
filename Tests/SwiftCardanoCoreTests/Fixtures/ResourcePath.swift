import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Address File Paths
let paymentAddressFilePath = (
    forResource: "test.payment",
    ofType: "addr",
    inDirectory: "data"
)

let stakeAddressFilePath = (
    forResource: "test.stake",
    ofType: "addr",
    inDirectory: "data"
)

// MARK: - Key File Paths
let paymentVerificationKeyFilePath = (
    forResource: "test.payment",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let paymentSigningKeyFilePath = (
    forResource: "test.payment",
    ofType: "skey",
    inDirectory: "data/keys"
)

let stakeVerificationKeyFilePath = (
    forResource: "test.stake",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let stakeSigningKeyFilePath = (
    forResource: "test.stake",
    ofType: "skey",
    inDirectory: "data/keys"
)

let committeeColdVerificationKeyFilePath = (
    forResource: "committee.cold",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let committeeColdSigningKeyFilePath = (
    forResource: "committee.cold",
    ofType: "skey",
    inDirectory: "data/keys"
)

let committeeHotVerificationKeyFilePath = (
    forResource: "committee.hot",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let committeeHotSigningKeyFilePath = (
    forResource: "committee.hot",
    ofType: "skey",
    inDirectory: "data/keys"
)

let stakePoolVerificationKeyFilePath = (
    forResource: "test.cold",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let stakePoolSigningKeyFilePath = (
    forResource: "test.cold",
    ofType: "skey",
    inDirectory: "data/keys"
)

let vrfVerificationKeyFilePath = (
    forResource: "test.vrf",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let vrfSigningKeyFilePath = (
    forResource: "test.vrf",
    ofType: "skey",
    inDirectory: "data/keys"
)

let drepVerificationKeyFilePath = (
    forResource: "test.drep",
    ofType: "vkey",
    inDirectory: "data/keys"
)
let drepSigningKeyFilePath = (
    forResource: "test.drep",
    ofType: "skey",
    inDirectory: "data/keys"
)

// MARK: - Certificate File Paths

let authCommitteeFilePath = (
    forResource: "test.auth",
    ofType: "cert",
    inDirectory: "data/certs"
)

let registerFilePath = (
    forResource: "test.stake-registration",
    ofType: "cert",
    inDirectory: "data/certs"
)

let stakeRegistrationFilePath = (
    forResource: "test.stake",
    ofType: "cert",
    inDirectory: "data/certs"
)

let stakeUnregisterFilePath = (
    forResource: "test.stake-unregister",
    ofType: "cert",
    inDirectory: "data/certs"
)

let stakeDeregistrationFilePath = (
    forResource: "test.stake-deregistration",
    ofType: "cert",
    inDirectory: "data/certs"
)

let stakeRegisterDelegateFilePath = (
    forResource: "test.stake-register-delegate",
    ofType: "cert",
    inDirectory: "data/certs"
)

let stakeDelegationFilePath = (
    forResource: "test.delegation",
    ofType: "cert",
    inDirectory: "data/certs"
)

let resignCommitteeColdFilePath = (
    forResource: "test.resignation",
    ofType: "cert",
    inDirectory: "data/certs"
)

let poolRegistrationFilePath = (
    forResource: "test.pool-registration",
    ofType: "cert",
    inDirectory: "data/certs"
)

let poolRetireFilePath = (
    forResource: "test.pool-retire",
    ofType: "cert",
    inDirectory: "data/certs"
)

let registerDRepFilePath = (
    forResource: "test.drep-reg",
    ofType: "cert",
    inDirectory: "data/certs"
)

let voteDelegateDRepFilePath = (
    forResource: "test.vote-deleg-drep",
    ofType: "cert",
    inDirectory: "data/certs"
)

let voteDelegateAlwaysAbstainFilePath = (
    forResource: "test.vote-deleg-always-abstain",
    ofType: "cert",
    inDirectory: "data/certs"
)

let voteDelegateAlwaysNoConfidenceFilePath = (
    forResource: "test.vote-deleg-always-no-confidence",
    ofType: "cert",
    inDirectory: "data/certs"
)

let voteDelegateScriptFilePath = (
    forResource: "test.vote-deleg-script",
    ofType: "cert",
    inDirectory: "data/certs"
)

// MARK: - DRep Paths
let drepIdFilePath = (
    forResource: "test.drep",
    ofType: "id",
    inDirectory: "data"
)
let drepHexIdFilePath = (
    forResource: "test.drep-hex",
    ofType: "id",
    inDirectory: "data"
)
let drepMetadataFilePath = (
    forResource: "drep",
    ofType: "jsonld",
    inDirectory: "data"
)
let drepMetadataHashFilePath = (
    forResource: "drepMetadataHash",
    ofType: "txt",
    inDirectory: "data"
)

// MARK: - Script Paths
let scriptHashFilePath = (
    forResource: "script",
    ofType: "hash",
    inDirectory: "data"
)

// MARK: - Pool Metadata Paths
let poolMetadataJSONFilePath = (
    forResource: "poolMetadata",
    ofType: "json",
    inDirectory: "data"
)

let poolMetadataHashFilePath = (
    forResource: "poolMetadataHash",
    ofType: "txt",
    inDirectory: "data"
)
