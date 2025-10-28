import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeDelegationTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    
    @Test func testInitialization() async throws {
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
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try StakeDelegation.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeDelegationCertificate?.payload.toHex
        
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
