import Foundation
import Testing

@testable import SwiftCardanoCore

//@Suite  struct SigningKeyTests {
//    @Test
//    func testSigningKeyGenerate() throws {
//        let signingKey = try SigningKey.generate()
//        #expect(
//            signingKey.payload.count > 0,
//            "Generated signing key payload should not be empty"
//        )
//    }
//    
//    @Test
//    func testSigningData() throws {
//        let signingKey = try SigningKey.generate()
//        let message = "Test message".data(using: .utf8)!
//        
//        let signature = try signingKey.sign(data: message)
//        #expect(signature.count > 0, "Signature should not be empty")
//    }
//    
//    @Test
//    func testToVerificationKey() throws {
//        let signingKey = try SigningKey.generate()
//        let verificationKey: VerificationKey = try signingKey.toVerificationKey()
//        
//        #expect(verificationKey.payload.count > 0, "Verification key payload should not be empty")
//    }
//    
//    @Test
//    func testSigningConsistency() throws {
//        let signingKey = try SigningKey.generate()
//        let message = "Consistency check".data(using: .utf8)!
//        
//        let signature1 = try signingKey.sign(data: message)
//        let signature2 = try signingKey.sign(data: message)
//        
//        #expect(signature1 == signature2, "Signatures for the same message must be identical")
//    }
//}
