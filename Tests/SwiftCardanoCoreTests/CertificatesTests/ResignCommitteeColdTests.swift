import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct ResignCommitteeColdTests {

    @Test func testInitialization() async throws {
        let verificationKeyHash = try VerificationKeyHash(
            payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        )
        let committeeColdCredential = CommitteeColdCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        
        let anchor = Anchor(
            anchorUrl: try Url("https://example.com"),
            anchorDataHash: try AnchorDataHash(
                payload: Data(repeating: 0, count: 32)
            )
        )

        let resignCommitteeCold = ResignCommitteeCold(
            committeeColdCredential: committeeColdCredential,
            anchor: anchor
        )
        
        #expect(ResignCommitteeCold.CODE.rawValue == 15)
        #expect(resignCommitteeCold.committeeColdCredential == committeeColdCredential)
        #expect(resignCommitteeCold.anchor == anchor)
    }

    @Test func testJSON() async throws {
        let cert = resignCommitteeColdCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try ResignCommitteeCold.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }

    @Test func testCBOR() async throws {
        let excpectedCBOR = resignCommitteeColdCertificate?.payload.toHex
        
        let coldVKey = committeeColdVerificationKey
        
        let committeeColdCredential = CommitteeColdCredential(
            credential: .verificationKeyHash(try coldVKey!.hash())
        )

        let resignCommitteeCold = ResignCommitteeCold(
            committeeColdCredential: committeeColdCredential
        )
        
        let cborData = try CBOREncoder().encode(resignCommitteeCold)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(ResignCommitteeCold.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == resignCommitteeCold)
    }
}
