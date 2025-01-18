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

func getCertificateJSON(forResource: String, ofType: String, inDirectory: String) throws -> CertificateJSON? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        return try CertificateJSON.load(from: filePath)
    } catch {
        Issue.record("Failed to load certificate from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

func getKeyPath(forResource: String, ofType: String, inDirectory: String) throws -> String? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    return filePath
    
//    do {
//        let key = try T.load(from: filePath)
//        return key
//    } catch {
//        Issue.record("Failed to load address from file: \(filePath)")
//        try #require(Bool(false))
//        return nil
//    }
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
var stakeRegistrationJSON: CertificateJSON? {
    do {
        return try getCertificateJSON(
            forResource: stakeRegistrationFilePath.forResource,
            ofType: stakeRegistrationFilePath.ofType,
            inDirectory: stakeRegistrationFilePath.inDirectory)
    } catch {
        return nil
    }
}

var authCommitteeJSON: CertificateJSON? {
    do {
        return try getCertificateJSON(
            forResource: authCommitteeFilePath.forResource,
            ofType: authCommitteeFilePath.ofType,
            inDirectory: authCommitteeFilePath.inDirectory)
    } catch {
        return nil
    }
}

// MARK: - Key Fixtures
var paymentVerificationKey: PaymentVerificationKey? {
    do {
        let keyPath = try getKeyPath(
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
        let keyPath = try getKeyPath(
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
        let keyPath = try getKeyPath(
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
        let keyPath = try getKeyPath(
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
        let keyPath = try getKeyPath(
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
        let keyPath = try getKeyPath(
            forResource: committeeHotSigningKeyFilePath.forResource,
            ofType: committeeHotSigningKeyFilePath.ofType,
            inDirectory: committeeHotSigningKeyFilePath.inDirectory
        )
        return try CommitteeHotSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
