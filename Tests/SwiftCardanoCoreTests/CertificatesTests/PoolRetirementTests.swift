import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct PoolRetirementTests {
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    let epoch = 540
    
    @Test func testInitialization() async throws {
        let poolRetirement = PoolRetirement(
            poolKeyHash: poolKeyHash,
            epoch: epoch
        )
        
        #expect(PoolRetirement.CODE.rawValue == 4)
        #expect(poolRetirement.poolKeyHash == poolKeyHash)
        #expect(poolRetirement.epoch == 540)
    }
    
    @Test func testJSON() async throws {
        let cert = poolRetirementCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try PoolRetirement.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = poolRetirementCertificate?.payload.toHex
        
        let cert = PoolRetirement(
            poolKeyHash: poolKeyHash,
            epoch: epoch
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(PoolRetirement.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
