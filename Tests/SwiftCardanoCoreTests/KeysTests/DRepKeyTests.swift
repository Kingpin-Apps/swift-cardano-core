import Foundation
import Testing
import SwiftNcal
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct DRepKeyTests {
    @Test func testVerificationKey() async throws {
        let VK = drepVerificationKey!
        
        let encodedData = try CBOREncoder().encode(VK)
        let encodedHex = encodedData.toHex
        
        let json = try VK.toTextEnvelope()
        
        let keyPath = try getFilePath(
            forResource: drepVerificationKeyFilePath.forResource,
            ofType: drepVerificationKeyFilePath.ofType,
            inDirectory: drepVerificationKeyFilePath.inDirectory
        )
        let jsonString = try String(
            contentsOfFile: keyPath!,
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = json!.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            Issue.record("Invalid JSON")
            return
        }
        
        let expectedPayload = Data([
            0xE0, 0x08, 0x90, 0xCC, 0x62, 0x5C, 0xB4, 0x63,
            0x91, 0x6C, 0xB7, 0xFE, 0xB2, 0xE2, 0xE0, 0x1B,
            0x93, 0x16, 0x9F, 0xE0, 0xF4, 0xF3, 0x70, 0x8A,
            0x9B, 0xCB, 0xF4, 0x84, 0xE0, 0x68, 0x3F, 0x97
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testSigningKey() async throws {
        let SK = drepSigningKey!
        
        let encodedData = try CBOREncoder().encode(SK)
        let encodedHex = encodedData.toHex
        
        let json = try SK.toTextEnvelope()
        
        let keyPath = try getFilePath(
            forResource: drepSigningKeyFilePath.forResource,
            ofType: drepSigningKeyFilePath.ofType,
            inDirectory: drepSigningKeyFilePath.inDirectory
        )
        let jsonString = try String(
            contentsOfFile: keyPath!,
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = json!.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            Issue.record("Invalid JSON")
            return
        }
        
        let expectedPayload = Data([
            0x1B, 0xCD, 0x73, 0xEE, 0x1A, 0x23, 0x80, 0x97,
            0x63, 0x70, 0xFB, 0xC6, 0x49, 0x28, 0xDB, 0x74,
            0x98, 0x72, 0x0F, 0x54, 0x99, 0xD2, 0xE0, 0xD9,
            0x62, 0xA3, 0xE4, 0xC3, 0x7D, 0xE5, 0x74, 0x1F
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testKeyGeneration() async throws {
        let sk = try DRepSigningKey.generate()
        let vk: DRepVerificationKey = try DRepVerificationKey.fromSigningKey(sk)
        let kp1 = DRepKeyPair(
            signingKey: sk,
            verificationKey: vk
        )
        let kp2 = try DRepKeyPair.fromSigningKey(sk)
        #expect(kp1 == kp2)
    }
    
    @Test func testSaveLoadSigningKey() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("drep.skey")
        
        // Remove file if it exists from previous test run
        try? FileManager.default.removeItem(atPath: tempFileURL.path)
        
        let sk = try DRepSigningKey.generate()
        try sk.save(to: tempFileURL.path)
        let loadedSK = try DRepSigningKey.load(from: tempFileURL.path)
        #expect(sk == loadedSK)
        try FileManager.default.removeItem(atPath: tempFileURL.path)
    }
}
