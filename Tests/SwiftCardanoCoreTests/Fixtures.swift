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
