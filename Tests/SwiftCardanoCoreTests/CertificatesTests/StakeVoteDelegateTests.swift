import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeVoteDelegateTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    
    let drep = DRep(credential: .verificationKeyHash(try! drepVerificationKey!.hash()))
    
    @Test func testInitialization() async throws {
        let stakeRegistration = StakeVoteDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            drep: drep
        )
        
        #expect(StakeVoteDelegate.CODE.rawValue == 10)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
        #expect(stakeRegistration.poolKeyHash == poolKeyHash)
        #expect(stakeRegistration.drep == drep)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeVoteDelegateCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try StakeVoteDelegate.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeVoteDelegateCertificate?.payload.toHex
        
        let cert = StakeVoteDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            drep: drep
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeVoteDelegate.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
