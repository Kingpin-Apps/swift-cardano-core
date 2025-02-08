import Foundation
import Testing
import SwiftNcal
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct CommitteeKeyTests {
    @Test func testColdVerificationKey() async throws {
        let VK = committeeColdVerificationKey!
        
        let encodedData = try CBOREncoder().encode(VK)
        let encodedHex = encodedData.toHex
        
        let json = try VK.toJSON()
        
        let keyPath = try getFilePath(
            forResource: committeeColdVerificationKeyFilePath.forResource,
            ofType: committeeColdVerificationKeyFilePath.ofType,
            inDirectory: committeeColdVerificationKeyFilePath.inDirectory
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
            0xA1, 0x13, 0xE3, 0xD3, 0x3C, 0x93, 0xF3, 0x91,
            0x9F, 0x7F, 0x21, 0x86, 0x6F, 0xD1, 0xD6, 0xEC,
            0x48, 0x9D, 0x8B, 0x04, 0x1B, 0xD0, 0xA5, 0x54,
            0xA0, 0xDB, 0xEA, 0xC7, 0x2E, 0x50, 0xEA, 0x1D
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testColdSigningKey() async throws {
        let SK = committeeColdSigningKey!
        
        let encodedData = try CBOREncoder().encode(SK)
        let encodedHex = encodedData.toHex
        
        let json = try SK.toJSON()
        
        let keyPath = try getFilePath(
            forResource: committeeColdSigningKeyFilePath.forResource,
            ofType: committeeColdSigningKeyFilePath.ofType,
            inDirectory: committeeColdSigningKeyFilePath.inDirectory
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
        
        print("hex1: \(encodedHex)")
        print("hex2: \(dict["cborHex"]!)")
        
        let expectedPayload = Data([
            0xC3, 0xCF, 0x40, 0x2A, 0x61, 0xB5, 0x3B, 0xFD,
            0x5B, 0x11, 0x02, 0xB5, 0x0E, 0x6F, 0x61, 0x85,
            0x06, 0xCC, 0x4C, 0x3C, 0x9F, 0x41, 0x57, 0xEB,
            0x1E, 0xE5, 0x05, 0xE3, 0x13, 0x70, 0x54, 0x8C
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testHotVerificationKey() async throws {
        let VK = committeeHotVerificationKey!
        
        let encodedData = try CBOREncoder().encode(VK)
        let encodedHex = encodedData.toHex
        
        let json = try VK.toJSON()
        
        let keyPath = try getFilePath(
            forResource: committeeHotVerificationKeyFilePath.forResource,
            ofType: committeeHotVerificationKeyFilePath.ofType,
            inDirectory: committeeHotVerificationKeyFilePath.inDirectory
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
            0x80, 0xD6, 0x08, 0xA7, 0xBE, 0xC6, 0xC4, 0x13,
            0xAC, 0x1E, 0x4D, 0xB9, 0xDB, 0x05, 0xCB, 0x0B,
            0xF4, 0x04, 0xFA, 0xD8, 0x0D, 0xDF, 0x25, 0x31,
            0xEF, 0x57, 0xC7, 0x55, 0x75, 0xC0, 0xB0, 0xF5
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testHotSigningKey() async throws {
        let SK = committeeHotSigningKey!
        
        let encodedData = try CBOREncoder().encode(SK)
        let encodedHex = encodedData.toHex
        
        let json = try SK.toJSON()
        
        let keyPath = try getFilePath(
            forResource: committeeHotSigningKeyFilePath.forResource,
            ofType: committeeHotSigningKeyFilePath.ofType,
            inDirectory: committeeHotSigningKeyFilePath.inDirectory
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
            0x8B, 0x52, 0x86, 0x8C, 0xA8, 0xAC, 0x2E, 0x8E,
            0xC2, 0x4F, 0x6A, 0xE7, 0xA8, 0x6E, 0xF3, 0x9A,
            0x1C, 0xDC, 0x53, 0x13, 0x5D, 0x4D, 0x93, 0xC0,
            0x14, 0xB2, 0x04, 0x71, 0xEA, 0x60, 0x27, 0x78
        ])
        
        #expect(encodedHex == dict["cborHex"])
        #expect(json == jsonString)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testColdKeyGeneration() async throws {
        let sk = try CommitteeColdSigningKey.generate()
        let vk: CommitteeColdVerificationKey = try CommitteeColdVerificationKey.fromSigningKey(sk)
        let kp1 = CommitteeColdKeyPair(
            signingKey: sk,
            verificationKey: vk
        )
        let kp2 = try CommitteeColdKeyPair.fromSigningKey(sk)
        #expect(kp1 == kp2)
    }
    
    @Test func testSaveLoadColdSigningKey() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("committeeColdSigningKey.skey")
        
        let sk = try CommitteeColdSigningKey.generate()
        try sk.save(to: tempFileURL.path)
        let loadedSK = try CommitteeColdSigningKey.load(from: tempFileURL.path)
        #expect(sk == loadedSK)
        try FileManager.default.removeItem(atPath: tempFileURL.path)
    }
}
