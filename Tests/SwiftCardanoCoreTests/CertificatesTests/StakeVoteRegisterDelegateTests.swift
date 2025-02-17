import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeVoteRegisterDelegateTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    let poolKeyHash = try! stakePoolVerificationKey!.poolKeyHash()
    
    let drep = DRep(credential: .verificationKeyHash(try! drepVerificationKey!.hash()))
    
    let coin: Coin = 2000000
    
    @Test func testInitialization() async throws {
        let stakeRegistration = StakeVoteRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            drep: drep,
            coin: coin
        )
        
        #expect(StakeVoteRegisterDelegate.CODE.rawValue == 13)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
        #expect(stakeRegistration.poolKeyHash == poolKeyHash)
        #expect(stakeRegistration.drep == drep)
        #expect(stakeRegistration.coin == coin)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeVoteRegisterDelegateCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try StakeVoteRegisterDelegate.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeVoteRegisterDelegateCertificate?.payload.toHex
        
        let cert = StakeVoteRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            drep: drep,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeVoteRegisterDelegate.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
