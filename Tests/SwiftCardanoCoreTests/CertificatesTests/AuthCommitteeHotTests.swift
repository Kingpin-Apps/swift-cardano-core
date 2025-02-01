import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct AuthCommitteeHotTests {

    @Test func testInitialization() async throws {
        let verificationKeyHash = VerificationKeyHash(
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
        
        #expect(AuthCommitteeHot.CODE.rawValue == 14)
        #expect(authCommitteeHot.committeeColdCredential == committeeColdCredential)
        #expect(authCommitteeHot.committeeHotCredential == committeeHotCredential)
    }

    @Test func testJSON() async throws {
        let cert = authCommitteeCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try AuthCommitteeHot.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }

    @Test func testCBOR() async throws {
        let excpectedCBOR = authCommitteeCertificate?.payload.toHex
        
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
