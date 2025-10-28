import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct VoteRegisterDelegateTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    
    let drep = DRep(credential: .verificationKeyHash(try! drepVerificationKey!.hash()))
    
    let coin: Coin = 2000000
    
    @Test func testInitialization() async throws {
        let stakeRegistration = VoteRegisterDelegate(
            stakeCredential: stakeCredential,
            drep: drep,
            coin: coin
        )
        
        #expect(VoteRegisterDelegate.CODE.rawValue == 12)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
        #expect(stakeRegistration.drep == drep)
        #expect(stakeRegistration.coin == coin)
    }
    
    @Test func testJSON() async throws {
        let cert = voteRegisterDelegateCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try VoteRegisterDelegate.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = voteRegisterDelegateCertificate?.payload.toHex
        
        let cert = VoteRegisterDelegate(
            stakeCredential: stakeCredential,
            drep: drep,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(VoteRegisterDelegate.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
