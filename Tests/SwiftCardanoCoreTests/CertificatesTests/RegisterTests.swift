import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct RegisterTests {
    let coin: Coin = 2000000
    
    @Test func testInitialization() async throws {
        let verificationKeyHash = VerificationKeyHash(
            payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        )
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        
        let stakeRegistration = Register(
            stakeCredential: stakeCredential,
            coin: coin
        )
        
        #expect(Register.CODE.rawValue == 7)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
        #expect(stakeRegistration.coin == coin)
    }
    
    @Test func testJSON() async throws {
        let cert = registerCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try Register.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = registerCertificate?.payload.toHex
        
        let credential = stakeAddress!.stakingPart
        
        guard case .verificationKeyHash(let verificationKeyHash) = credential else {
            Issue.record("Expected verificationKeyHash")
            return
        }
        
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        
        let cert = Register(
            stakeCredential: stakeCredential,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(Register.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
