import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct CredentialTests {
    
    let test_addr: Address = try! Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
    
    @Test func testVerificationKeyHashInitialization() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let verificationKeyHash = VerificationKeyHash(payload: payload)
        let credential = Credential(credential: .verificationKeyHash(verificationKeyHash))
        
        let cborData = try CBOREncoder().encode(credential)
        let decoded = try CBORDecoder().decode(Credential.self, from: cborData)
        
        #expect(credential.code == 0)
        #expect(credential.credential == .verificationKeyHash(verificationKeyHash))
        #expect(decoded == credential)
    }
    
    @Test func testScriptHashInitialization() async throws {
        let payload = Data(repeating: 1, count: SCRIPT_HASH_SIZE)
        let scriptHash = ScriptHash(payload: payload)
        let credential = Credential(credential: .scriptHash(scriptHash))
        let cborData = try CBOREncoder().encode(credential)
        let decoded = try CBORDecoder().decode(Credential.self, from: cborData)
        
        #expect(credential.code == 1)
        #expect(credential.credential == .scriptHash(scriptHash))
        #expect(decoded == credential)
    }
    
    @Test func testEquality() async throws {
        let payload1 = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let payload2 = Data(repeating: 1, count: VERIFICATION_KEY_HASH_SIZE)
        
        let verificationKeyHash1 = VerificationKeyHash(payload: payload1)
        let verificationKeyHash2 = VerificationKeyHash(payload: payload2)
        
        let credential1 = Credential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential2 = Credential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential3 = Credential(credential: .verificationKeyHash(verificationKeyHash2))
        
        #expect(credential1 == credential2)
        #expect(credential1 != credential3)
    }
}
