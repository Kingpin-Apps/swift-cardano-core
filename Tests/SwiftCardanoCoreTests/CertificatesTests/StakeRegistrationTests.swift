import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeRegistrationTests {
    @Test func testInitialization() async throws {
        let verificationKeyHash = try VerificationKeyHash(
            payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        )
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        
        let stakeRegistration = StakeRegistration(stakeCredential: stakeCredential)
        
        #expect(StakeRegistration.CODE.rawValue == 0)
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        guard let certFilePath = Bundle.module.path(forResource: "test.stake", ofType: "cert", inDirectory: "data/certs") else {
            Issue.record("File not found: test.stake.cert")
            return
        }
        
        let cert = try StakeRegistration.load(from: certFilePath)
        
        let json = try cert.toJSON()
        let certFromJSON = try StakeRegistration.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeRegistrationCertificate?.payload.toHex
        
        let credential = stakeAddress!.stakingPart
        
        guard case .verificationKeyHash(let verificationKeyHash) = credential else {
            Issue.record("Expected verificationKeyHash")
            return
        }
        
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        let stakeRegistration = StakeRegistration(stakeCredential: stakeCredential)
        
        let cborData = try CBOREncoder().encode(stakeRegistration)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(StakeRegistration.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == stakeRegistration)
    }
}
