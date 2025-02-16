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
let stakeRegistrationFilePath = (
    forResource: "test.stake",
    ofType: "cert",
    inDirectory: "data/certs"
)
let authCommitteeFilePath = (
    forResource: "test.auth",
    ofType: "cert",
    inDirectory: "data/certs"
)

let resignCommitteeColdFilePath = (
    forResource: "test.resignation",
    ofType: "cert",
    inDirectory: "data/certs"
)

let poolRegistrationFilePath = (
    forResource: "test.pool",
    ofType: "cert",
    inDirectory: "data/certs"
)

let poolRetireFilePath = (
    forResource: "test.dereg",
    ofType: "cert",
    inDirectory: "data/certs"
)

let registerFilePath = (
    forResource: "test.register",
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
let stakeDelegationFilePath = (
    forResource: "test.delegation",
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

// MARK: - Helper Functions
func getTestAddress(forResource: String, ofType: String, inDirectory: String) throws -> Address? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        return try Address.load(from: filePath)
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

func getFilePath(forResource: String, ofType: String, inDirectory: String) throws -> String? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    return filePath
}

func getVerificationKey<T>(forResource: String, ofType: String, inDirectory: String) throws -> T? where T: VerificationKey {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        let key = try T.load(from: filePath)
        return key
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

// MARK: - Address Fixtures
var paymentAddress: Address? {
    do {
        return try getTestAddress(
            forResource: paymentAddressFilePath.forResource,
            ofType: paymentAddressFilePath.ofType,
            inDirectory: paymentAddressFilePath.inDirectory)
    } catch {
        return nil
    }
}

var stakeAddress: Address? {
    do {
        return try getTestAddress(
            forResource: stakeAddressFilePath.forResource,
            ofType: stakeAddressFilePath.ofType,
            inDirectory: stakeAddressFilePath.inDirectory)
    } catch {
        return nil
    }
}

// MARK: - Certificate Fixtures
var stakeRegistrationCertificate: StakeRegistration? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeRegistrationFilePath.forResource,
            ofType: stakeRegistrationFilePath.ofType,
            inDirectory: stakeRegistrationFilePath.inDirectory
        )
        return try StakeRegistration.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var authCommitteeCertificate: AuthCommitteeHot? {
    do {
        let certificatePath = try getFilePath(
            forResource: authCommitteeFilePath.forResource,
            ofType: authCommitteeFilePath.ofType,
            inDirectory: authCommitteeFilePath.inDirectory
        )
        return try AuthCommitteeHot.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var resignCommitteeColdCertificate: ResignCommitteeCold? {
    do {
        let certificatePath = try getFilePath(
            forResource: resignCommitteeColdFilePath.forResource,
            ofType: resignCommitteeColdFilePath.ofType,
            inDirectory: resignCommitteeColdFilePath.inDirectory
        )
        return try ResignCommitteeCold.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var poolRegistrationCertificate: PoolRegistration? {
    do {
        let certificatePath = try getFilePath(
            forResource: poolRegistrationFilePath.forResource,
            ofType: poolRegistrationFilePath.ofType,
            inDirectory: poolRegistrationFilePath.inDirectory
        )
        return try PoolRegistration.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var poolRetirementCertificate: PoolRetirement? {
    do {
        let certificatePath = try getFilePath(
            forResource: poolRetireFilePath.forResource,
            ofType: poolRetireFilePath.ofType,
            inDirectory: poolRetireFilePath.inDirectory
        )
        return try PoolRetirement.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var registerCertificate: Register? {
    do {
        let certificatePath = try getFilePath(
            forResource: registerFilePath.forResource,
            ofType: registerFilePath.ofType,
            inDirectory: registerFilePath.inDirectory
        )
        return try Register.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var registerDRepCertificate: RegisterDRep? {
    do {
        let certificatePath = try getFilePath(
            forResource: registerDRepFilePath.forResource,
            ofType: registerDRepFilePath.ofType,
            inDirectory: registerDRepFilePath.inDirectory
        )
        return try RegisterDRep.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var voteDelegateDRepCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateDRepFilePath.forResource,
            ofType: voteDelegateDRepFilePath.ofType,
            inDirectory: voteDelegateDRepFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
var voteDelegateAlwaysAbstainCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateAlwaysAbstainFilePath.forResource,
            ofType: voteDelegateAlwaysAbstainFilePath.ofType,
            inDirectory: voteDelegateAlwaysAbstainFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
var voteDelegateAlwaysNoConfidenceCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateAlwaysNoConfidenceFilePath.forResource,
            ofType: voteDelegateAlwaysNoConfidenceFilePath.ofType,
            inDirectory: voteDelegateAlwaysNoConfidenceFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
var voteDelegateScriptCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateScriptFilePath.forResource,
            ofType: voteDelegateScriptFilePath.ofType,
            inDirectory: voteDelegateScriptFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
var stakeDelegationCertificate: StakeDelegation? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeDelegationFilePath.forResource,
            ofType: stakeDelegationFilePath.ofType,
            inDirectory: stakeDelegationFilePath.inDirectory
        )
        return try StakeDelegation.load(from: certificatePath!)
    } catch {
        return nil
    }
}

// MARK: - Key Fixtures
var paymentVerificationKey: PaymentVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: paymentVerificationKeyFilePath.forResource,
            ofType: paymentVerificationKeyFilePath.ofType,
            inDirectory: paymentVerificationKeyFilePath.inDirectory
        )
        return try PaymentVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var stakeVerificationKey: StakeVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakeVerificationKeyFilePath.forResource,
            ofType: stakeVerificationKeyFilePath.ofType,
            inDirectory: stakeVerificationKeyFilePath.inDirectory
        )
        return try StakeVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}


var committeeColdVerificationKey: CommitteeColdVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeColdVerificationKeyFilePath.forResource,
            ofType: committeeColdVerificationKeyFilePath.ofType,
            inDirectory: committeeColdVerificationKeyFilePath.inDirectory
        )
        return try CommitteeColdVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
var committeeColdSigningKey: CommitteeColdSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeColdSigningKeyFilePath.forResource,
            ofType: committeeColdSigningKeyFilePath.ofType,
            inDirectory: committeeColdSigningKeyFilePath.inDirectory
        )
        return try CommitteeColdSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}


var committeeHotVerificationKey: CommitteeHotVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeHotVerificationKeyFilePath.forResource,
            ofType: committeeHotVerificationKeyFilePath.ofType,
            inDirectory: committeeHotVerificationKeyFilePath.inDirectory
        )
        return try CommitteeHotVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
var committeeHotSigningKey: CommitteeHotSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeHotSigningKeyFilePath.forResource,
            ofType: committeeHotSigningKeyFilePath.ofType,
            inDirectory: committeeHotSigningKeyFilePath.inDirectory
        )
        return try CommitteeHotSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}


var stakePoolVerificationKey: StakePoolVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakePoolVerificationKeyFilePath.forResource,
            ofType: stakePoolVerificationKeyFilePath.ofType,
            inDirectory: stakePoolVerificationKeyFilePath.inDirectory
        )
        return try StakePoolVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
var stakePoolSigningKey: StakePoolSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakePoolSigningKeyFilePath.forResource,
            ofType: stakePoolSigningKeyFilePath.ofType,
            inDirectory: stakePoolSigningKeyFilePath.inDirectory
        )
        return try StakePoolSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var vrfVerificationKey: VRFVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: vrfVerificationKeyFilePath.forResource,
            ofType: vrfVerificationKeyFilePath.ofType,
            inDirectory: vrfVerificationKeyFilePath.inDirectory
        )
        return try VRFVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
var vrfSigningKey: VRFSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: vrfSigningKeyFilePath.forResource,
            ofType: vrfSigningKeyFilePath.ofType,
            inDirectory: vrfSigningKeyFilePath.inDirectory
        )
        return try VRFSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var drepVerificationKey: DRepVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: drepVerificationKeyFilePath.forResource,
            ofType: drepVerificationKeyFilePath.ofType,
            inDirectory: drepVerificationKeyFilePath.inDirectory
        )
        return try DRepVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
var drepSigningKey: DRepSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: drepSigningKeyFilePath.forResource,
            ofType: drepSigningKeyFilePath.ofType,
            inDirectory: drepSigningKeyFilePath.inDirectory
        )
        return try DRepSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

// MARK: - DRep Fixtures
var drepId: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepIdFilePath.forResource,
            ofType: drepIdFilePath.ofType,
            inDirectory: drepIdFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
var drepHexId: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepHexIdFilePath.forResource,
            ofType: drepHexIdFilePath.ofType,
            inDirectory: drepHexIdFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
var drepMetadata: DRepMetadata? {
    do {
        let filePath = try getFilePath(
            forResource: drepMetadataFilePath.forResource,
            ofType: drepMetadataFilePath.ofType,
            inDirectory: drepMetadataFilePath.inDirectory
        )
        return try DRepMetadata.load(from: filePath!)
    } catch {
        return nil
    }
}
var drepMetadataHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepMetadataHashFilePath.forResource,
            ofType: drepMetadataHashFilePath.ofType,
            inDirectory: drepMetadataHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}

// MARK: - Script Fixtures
var scriptHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: scriptHashFilePath.forResource,
            ofType: scriptHashFilePath.ofType,
            inDirectory: scriptHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}

// MARK: - Pool Meteadata Fixtures
var poolMetadataJSON: PoolMetadata? {
    do {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        return try PoolMetadata.load(from: filePath!)
    } catch {
        return nil
    }
}
var poolMetadataHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: poolMetadataHashFilePath.forResource,
            ofType: poolMetadataHashFilePath.ofType,
            inDirectory: poolMetadataHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
