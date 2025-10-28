import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeRegisterDelegateTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    
    let coin: Coin = 2000000
    
    @Test func testInitialization() async throws {
        let stakeRegistration = StakeRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            coin: coin
        )
        
        #expect(StakeRegisterDelegate.CODE.rawValue == 11)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeRegisterDelegateCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try StakeRegisterDelegate.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeRegisterDelegateCertificate?.payload.toHex
        
        let cert = StakeRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeRegisterDelegate.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
