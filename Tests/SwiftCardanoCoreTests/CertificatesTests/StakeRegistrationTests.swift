import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeRegistrationTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    @Test func testInitialization() async throws {
        let stakeRegistration = StakeRegistration(stakeCredential: stakeCredential)
        
        #expect(StakeRegistration.CODE.rawValue == 0)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeRegistrationCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try StakeRegistration.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeRegistrationCertificate?.payload.toHex
        
        let cert = StakeRegistration(stakeCredential: stakeCredential)
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeRegistration.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
