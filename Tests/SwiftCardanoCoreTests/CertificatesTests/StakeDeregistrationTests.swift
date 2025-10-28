import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeDeregistrationTests {
    let stakeCredential = StakeCredential(
        credential: .verificationKeyHash(try! stakeVerificationKey!.hash())
    )
    
    @Test func testInitialization() async throws {
        let stakeRegistration = StakeDeregistration(stakeCredential: stakeCredential)
        
        #expect(StakeDeregistration.CODE.rawValue == 1)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        let cert = stakeDeregistrationCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try StakeDeregistration.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeDeregistrationCertificate?.payload.toHex
        
        let cert = StakeDeregistration(stakeCredential: stakeCredential)
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeDeregistration.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
