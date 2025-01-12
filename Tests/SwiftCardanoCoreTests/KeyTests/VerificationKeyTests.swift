import Foundation
import Testing

@testable import SwiftCardanoCore

@Suite
struct VerificationKeyTests {
    
    @Test
    func testVerificationKeyHash() throws {
        let verificationKey = VerificationKey(payload: Data(repeating: 0xAB, count: 32))
        let hash = try verificationKey.hash()
        
        #expect(hash.payload.count > 0, "Verification key hash should not be empty")
    }
    
    @Test
    func testVerificationKeyFromSigningKey() throws {
        let signingKey = try SigningKey.generate()
        let verificationKey: VerificationKey = try VerificationKey.fromSigningKey(signingKey)
        
        #expect(verificationKey.payload.count > 0, "Verification key payload should not be empty")
    }
    
    @Test
    func testVerificationKeyEquality() throws {
        let payload = Data(repeating: 0x01, count: 32)
        let key1 = VerificationKey(payload: payload)
        let key2 = VerificationKey(payload: payload)
        
        #expect(key1 == key2, "Verification keys with the same payload should be equal")
    }
    
    @Test
    func testVerificationKeyInequality() throws {
        let key1 = VerificationKey(payload: Data(repeating: 0x01, count: 32))
        let key2 = VerificationKey(payload: Data(repeating: 0x02, count: 32))
        
        #expect(key1 != key2, "Verification keys with different payloads should not be equal")
    }
}
