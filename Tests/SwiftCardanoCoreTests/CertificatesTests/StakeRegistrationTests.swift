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
        #expect(stakeRegistration.stakeCredential == stakeCredential)
    }
    
    @Test func testJSON() async throws {
        guard let certFilePath = Bundle.module.path(forResource: "test.stake", ofType: "cert", inDirectory: "data/certs") else {
            Issue.record("File not found: test.stake.cert")
            return
        }
        
        let certJSON = try CertificateJSON.load(from: certFilePath)
        let cert = try Certificate.fromCertificateJSON(certJSON)
        
        guard case .stakeRegistration(let stakeRegistration) = cert else {
            Issue.record("Expected stakeRegistration")
            return
        }
        
        let json = cert.toCertificateJSON()
        #expect(stakeRegistration.code == 0)
        #expect(certJSON == json)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = stakeRegistrationJSON?.payload.toHex
        
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
        let stakeCredentialCBORHex = cborData.toHex
        
        let stakeRegistrationFromCBOR = try CBORDecoder().decode(StakeRegistration.self, from: cborData)
        
        #expect(stakeCredentialCBORHex == excpectedCBOR)
        #expect(stakeRegistrationFromCBOR == stakeRegistration)
    }
}
