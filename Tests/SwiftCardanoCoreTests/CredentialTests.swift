import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct CredentialTests {
    
    let test_addr: Address = try! Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
    
    @Test func testVerificationKeyHashInitialization() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let verificationKeyHash = VerificationKeyHash(payload: payload)
        let credential = StakeCredential(credential: .verificationKeyHash(verificationKeyHash))
        
        let cborData = try CBOREncoder().encode(credential)
        let decoded = try CBORDecoder().decode(StakeCredential.self, from: cborData)
        
        #expect(credential.code == 0)
        #expect(credential.credential == .verificationKeyHash(verificationKeyHash))
        #expect(decoded == credential)
    }
    
    @Test func testScriptHashInitialization() async throws {
        let payload = Data(repeating: 1, count: SCRIPT_HASH_SIZE)
        let scriptHash = ScriptHash(payload: payload)
        let credential = StakeCredential(credential: .scriptHash(scriptHash))
        let cborData = try CBOREncoder().encode(credential)
        let decoded = try CBORDecoder().decode(StakeCredential.self, from: cborData)
        
        #expect(credential.code == 1)
        #expect(credential.credential == .scriptHash(scriptHash))
        #expect(decoded == credential)
    }
    
    @Test func testEquality() async throws {
        let payload1 = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let payload2 = Data(repeating: 1, count: VERIFICATION_KEY_HASH_SIZE)
        
        let verificationKeyHash1 = VerificationKeyHash(payload: payload1)
        let verificationKeyHash2 = VerificationKeyHash(payload: payload2)
        
        let credential1 = StakeCredential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential2 = StakeCredential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential3 = StakeCredential(credential: .verificationKeyHash(verificationKeyHash2))
        
        #expect(credential1 == credential2)
        #expect(credential1 != credential3)
    }
    
    @Test func testDRepCredential() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let bech32 = "drep1ygqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq7vlc9n"
        
        let verificationKeyHash = VerificationKeyHash(payload: payload)
        let credential1 = DRepCredential(credential: .verificationKeyHash(verificationKeyHash))
        let credential2 = try DRepCredential(from: bech32)
        let credential3 = try DRepCredential(from: payload, as: .keyHash)
        
        #expect(credential1 == credential2)
        #expect(credential1 == credential3)
        #expect(try credential1.id() == bech32)
    }
    
    @Test func testCommitteeColdCredential() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let bech32 = "cc_cold1zvqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6kflvs"
        
        let verificationKeyHash = ScriptHash(payload: payload)
        let credential1 = CommitteeColdCredential(
            credential: .scriptHash(verificationKeyHash)
        )
        let credential2 = try CommitteeColdCredential(from: bech32)
        let credential3 = try CommitteeColdCredential(
            from: payload,
            as: .scriptHash
        )
        
        #expect(credential1 == credential2)
        #expect(credential1 == credential3)
        #expect(try credential1.id() == bech32)
    }
    
    @Test func testCommitteeHotCredential() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let bech32 = "cc_hot1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqvcdjk7"
        
        let verificationKeyHash = VerificationKeyHash(payload: payload)
        let credential1 = CommitteeHotCredential(credential: .verificationKeyHash(verificationKeyHash))
        let credential2 = try CommitteeHotCredential(from: bech32)
        let credential3 = try CommitteeHotCredential(from: payload, as: .keyHash)
        
        #expect(credential1 == credential2)
        #expect(credential1 == credential3)
        #expect(try credential1.id() == bech32)
    }
}
