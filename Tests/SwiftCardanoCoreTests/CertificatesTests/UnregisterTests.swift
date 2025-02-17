import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct UnregisterTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    let coin: Coin = 2000000
    
    @Test func testInitialization() async throws {
        let stakeRegistration = Unregister(
            stakeCredential: stakeCredential,
            coin: coin
        )
        
        #expect(Unregister.CODE.rawValue == 8)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeUnregisterCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try Unregister.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeUnregisterCertificate?.payload.toHex
        
        let cert = Unregister(
            stakeCredential: stakeCredential,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(Unregister.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
