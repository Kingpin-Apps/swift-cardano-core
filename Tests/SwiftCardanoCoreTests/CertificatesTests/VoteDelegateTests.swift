import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

let dreps = [
    DRep(credential: .verificationKeyHash(try! drepVerificationKey!.hash())),
    DRep(
        credential:
                .scriptHash(ScriptHash(payload: scriptHash!.hexStringToData))
    ),
    DRep(credential: .alwaysAbstain),
    DRep(credential: .alwaysNoConfidence),
]

let voteDelegCerts =  [
    voteDelegateDRepCertificate!,
    voteDelegateScriptCertificate!,
    voteDelegateAlwaysAbstainCertificate!,
    voteDelegateAlwaysNoConfidenceCertificate!
]

@Suite struct VoteDelegateTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    @Test("Test Initialization", arguments: dreps)
    func testInitialization(drep: DRep) async throws {
        let voteDelegate = VoteDelegate(
            stakeCredential: stakeCredential,
            drep: drep
        )
        
        #expect(VoteDelegate.CODE.rawValue == 9)
        #expect(voteDelegate.stakeCredential == stakeCredential)
        #expect(voteDelegate.drep == drep)
    }
    
    @Test("Test JSON", arguments: voteDelegCerts)
    func testJSON(cert: VoteDelegate) async throws {
        let json = try cert.toTextEnvelope()
        let certFromJSON = try VoteDelegate.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test("Test CBOR", arguments: zip(voteDelegCerts, dreps))
    func testToFromCBOR(voteDelegate: VoteDelegate, drep: DRep) async throws {
        let excpectedCBOR = voteDelegate.payload.toHex
        
        let cert = VoteDelegate(
            stakeCredential: stakeCredential,
            drep: drep
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(VoteDelegate.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
