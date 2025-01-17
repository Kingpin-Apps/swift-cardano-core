import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct StakeRegistrationTests {
    
    let test_addr: Address = try! Address.fromPrimitive("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
    
    
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
    
    @Test func testDecode() async throws {
        guard let certFilePath = Bundle.module.path(forResource: "test.stake", ofType: "cert", inDirectory: "data") else {
            Issue.record("File not found: test.stake.cert")
            return
        }
        
        let stakeRegistrationCert = try StakeRegistration.load(from: certFilePath)
        
    }
    
    @Test func testStakeRegistrationToFromCBOR() async throws {
        let excpectedCBOR = "82008200581c4828a2dadba97ca9fd0cdc99975899470c219bdc0d828cfa6ddf6d69"
        
        let credential = test_addr.stakingPart
        
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
