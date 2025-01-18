import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct AuthCommitteeHotTests {

    @Test func testInitialization() async throws {
        let verificationKeyHash = try VerificationKeyHash(
            payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        )
        let committeeColdCredential = CommitteeColdCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        let committeeHotCredential = CommitteeHotCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )

        let authCommitteeHot = AuthCommitteeHot(
            committeeColdCredential: committeeColdCredential,
            committeeHotCredential: committeeHotCredential
        )

        #expect(authCommitteeHot.committeeColdCredential == committeeColdCredential)
        #expect(authCommitteeHot.committeeHotCredential == committeeHotCredential)
        #expect(authCommitteeHot.code == 14)
    }

    @Test func testJSON() async throws {
        guard let certFilePath = Bundle.module.path(forResource: "test.auth", ofType: "cert", inDirectory: "data/certs") else {
            Issue.record("File not found: test.stake.cert")
            return
        }
        
        let certJSON = try CertificateJSON.load(from: certFilePath)
        let cert = try Certificate.fromCertificateJSON(certJSON)
        
        guard case .authCommitteeHot(let authCommitteeHot) = cert else {
            Issue.record("Expected stakeRegistration")
            return
        }
        
        let json = cert.toCertificateJSON()
        #expect(authCommitteeHot.code == 14)
        #expect(certJSON == json)
    }

    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = authCommitteeJSON?.payload.toHex
        
        let coldVKey = committeeColdVerificationKey
        let hotVKey = committeeHotVerificationKey
        
        let committeeColdCredential = CommitteeColdCredential(
            credential: .verificationKeyHash(try coldVKey!.hash())
        )
        let committeeHotCredential = CommitteeHotCredential(
            credential: .verificationKeyHash(try hotVKey!.hash())
        )

        let authCommitteeHot = AuthCommitteeHot(
            committeeColdCredential: committeeColdCredential,
            committeeHotCredential: committeeHotCredential
        )
        
        let cborData = try CBOREncoder().encode(authCommitteeHot)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(AuthCommitteeHot.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == authCommitteeHot)
    }
}
