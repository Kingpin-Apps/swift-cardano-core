import Testing
import Foundation
@testable import SwiftCardanoCore

struct CredentialTests {
    
    @Test func testVerificationKeyHashInitialization() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let verificationKeyHash = try VerificationKeyHash(payload: payload)
        let credential = Credential(credential: .verificationKeyHash(verificationKeyHash))
        
        #expect(credential.code == 0)
        #expect(credential.credential == .verificationKeyHash(verificationKeyHash))
    }
    
    @Test func testScriptHashInitialization() async throws {
        let payload = Data(repeating: 1, count: SCRIPT_HASH_SIZE)
        let scriptHash = try ScriptHash(payload: payload)
        let credential = Credential(credential: .scriptHash(scriptHash))
        
        #expect(credential.code == 1)
        #expect(credential.credential == .scriptHash(scriptHash))
    }
    
    @Test func testFromPrimitiveValidVerificationKeyHash() async throws {
        let payload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let primitive = [0, payload] as [Any]
        let verificationKeyHash = try VerificationKeyHash(payload: payload)
        
        let credential: Credential = try Credential.fromPrimitive(primitive)
        #expect(credential.code == 0)
        #expect(credential.credential == .verificationKeyHash(verificationKeyHash))
    }
    
    @Test func testFromPrimitiveValidScriptHash() async throws {
        let payload = Data(repeating: 1, count: SCRIPT_HASH_SIZE)
        let primitive = [1, payload] as [Any]
        let scriptHash = try ScriptHash(payload: payload)
        
        let credential: Credential = try Credential.fromPrimitive(primitive)
        #expect(credential.code == 1)
        #expect(credential.credential == .scriptHash(scriptHash))
    }
    
    @Test func testFromPrimitiveInvalidType() async throws {
        let invalidPrimitive = [2, Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)] as [Any]
        
        #expect(throws: CardanoCoreError.self) {
            let _: Credential = try Credential.fromPrimitive(invalidPrimitive)
        }
    }
    
    @Test func testFromPrimitiveInvalidDataStructure() async throws {
        let invalidPrimitive = "invalid_data"
        
        #expect(throws: CardanoCoreError.self) {
            let _: Credential = try Credential.fromPrimitive(invalidPrimitive)
        }
    }
    
    @Test func testEquality() async throws {
        let payload1 = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)
        let payload2 = Data(repeating: 1, count: VERIFICATION_KEY_HASH_SIZE)
        
        let verificationKeyHash1 = try VerificationKeyHash(payload: payload1)
        let verificationKeyHash2 = try VerificationKeyHash(payload: payload2)
        
        let credential1 = Credential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential2 = Credential(credential: .verificationKeyHash(verificationKeyHash1))
        let credential3 = Credential(credential: .verificationKeyHash(verificationKeyHash2))
        
        #expect(credential1 == credential2)
        #expect(credential1 != credential3)
    }
}
