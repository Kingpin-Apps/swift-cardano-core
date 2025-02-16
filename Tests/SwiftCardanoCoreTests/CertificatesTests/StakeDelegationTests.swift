import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeDelegationTests {
    @Test func testInitialization() async throws {
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(try stakeVerificationKey!.hash())
        )
        let poolKeyHash = try stakePoolVerificationKey!.poolKeyHash()
        
        let stakeDelegation = StakeDelegation(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash
        )
        
        #expect(StakeDelegation.CODE.rawValue == 2)
        #expect(stakeDelegation.stakeCredential == stakeCredential)
        #expect(stakeDelegation.poolKeyHash == poolKeyHash)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeDelegationCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try StakeDelegation.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeDelegationCertificate?.payload.toHex
        
        let credential = stakeAddress!.stakingPart
        
        guard case .verificationKeyHash(let verificationKeyHash) = credential else {
            Issue.record("Expected verificationKeyHash")
            return
        }
        
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        let poolKeyHash = try stakePoolVerificationKey!.poolKeyHash()
        let cert = StakeDelegation(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeDelegation.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
