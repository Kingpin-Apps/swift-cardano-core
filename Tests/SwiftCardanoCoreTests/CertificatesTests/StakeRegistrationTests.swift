import Testing
import Foundation
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
    
    @Test func testStakeCredentialVerificationKeyHash() async throws {
        let excpectedCBOR = "8200581c4828a2dadba97ca9fd0cdc99975899470c219bdc0d828cfa6ddf6d69"
        
        let credential = test_addr.stakingPart
        
        guard case .verificationKeyHash(let verificationKeyHash) = credential else {
            Issue.record("Expected verificationKeyHash")
            return
        }
        
        let stakeCredential = StakeCredential(
            credential: .verificationKeyHash(verificationKeyHash)
        )
        let stakeCredentialCBORHex = try stakeCredential.toCBOR().toHexString()
        
        let stakeRegistrationFromCBOR = try StakeCredential.fromCBOR(
            stakeCredentialCBORHex.hexStringToData
        )
        #expect(stakeCredentialCBORHex == excpectedCBOR)
        #expect(stakeRegistrationFromCBOR == stakeCredential)
    }
    
//    @Test func testFromPrimitiveValidData() async throws {
//        let stakeCredentialData = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
//        let primitive = [0, stakeCredentialData] as [Any]
//        
//        let stakeRegistration: StakeRegistration = try StakeRegistration.fromPrimitive(primitive)
//        #expect(stakeRegistration.code == 0)
//        #expect(stakeRegistration.stakeCredential == StakeCredential.verificationKeyHash(
//            VerificationKeyHash(payload: stakeCredentialData)
//        ))
//    }
//    
//    @Test func testFromPrimitiveInvalidType() async throws {
//        let invalidPrimitive = [1, Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)] as [Any]
//        
//        #expect(throws: CardanoCoreError.self) {
//            let _: StakeRegistration = try StakeRegistration.fromPrimitive(invalidPrimitive)
//        }
//    }
//    
//    @Test func testFromPrimitiveInvalidDataStructure() async throws {
//        let invalidPrimitive = "invalid_data"
//        
//        #expect(throws: CardanoCoreError.self) {
//            let _: StakeRegistration = try StakeRegistration.fromPrimitive(invalidPrimitive)
//        }
//    }
//    
//    @Test func testEquality() async throws {
//        let stakeCredential1 = try StakeCredential.verificationKeyHash(
//            VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
//        )
//        let stakeCredential2 = try StakeCredential.verificationKeyHash(
//            VerificationKeyHash(payload: Data(repeating: 1, count: VERIFICATION_KEY_HASH_SIZE))
//        )
//        
//        let stakeRegistration1 = StakeRegistration(stakeCredential: stakeCredential1)
//        let stakeRegistration2 = StakeRegistration(stakeCredential: stakeCredential1)
//        let stakeRegistration3 = StakeRegistration(stakeCredential: stakeCredential2)
//        
//        #expect(stakeRegistration1 == stakeRegistration2)
//        #expect(stakeRegistration1 != stakeRegistration3)
//    }
//    
//    @Test func testDescription() async throws {
//        let stakeCredential = try StakeCredential.verificationKeyHash(
//            VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
//        )
//        let stakeRegistration = StakeRegistration(stakeCredential: stakeCredential)
//        
//        let expectedDescription = "StakeRegistration(stakeCredential: \(stakeCredential))"
//        #expect(stakeRegistration.description == expectedDescription)
//    }
}
