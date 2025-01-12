import Foundation
import Testing
import SwiftNcal
@testable import SwiftCardanoCore

// MARK: - Sample JSON Keys
let stakePoolSKey = [
    "type": "StakePoolSigningKey_ed25519",
    "description": "StakePoolSigningKey_ed25519",
    "cborHex": "582044181bd0e6be21cea5b0751b8c6d4f88a5cb2d5dfec31a271add617f7ce559a9"
]

let stakePoolVKey = [
    "type": "StakePoolVerificationKey_ed25519",
    "description": "StakePoolVerificationKey_ed25519",
    "cborHex": "5820354ce32da92e7116f6c70e9be99a3a601d33137d0685ab5b7e2ff5b656989299"
]

// MARK: - Test Suite
@Suite struct StakePoolKeyTests {
    let stakePoolSKeyJSON = """
    {
        "type": "\(stakePoolSKey["type"]!)",
        "description": "\(stakePoolSKey["description"]!)",
        "cborHex": "\(stakePoolSKey["cborHex"]!)"
    }
    """
    let stakePoolVKeyJSON = """
    {
        "type": "\(stakePoolVKey["type"]!)",
        "description": "\(stakePoolVKey["description"]!)",
        "cborHex": "\(stakePoolVKey["cborHex"]!)"
    }
    """
    
    
    @Test func testStakePoolSKey() async throws {
        let SK = try! StakePoolSigningKey.fromJSON(stakePoolSKeyJSON)
        let cborHex = try SK.toCBORHex()
        let json = try SK.toJSON()
        let expectedPayload = Data([
            0x44, 0x18, 0x1b, 0xd0, 0xe6, 0xbe, 0x21, 0xce,
            0xa5, 0xb0, 0x75, 0x1b, 0x8c, 0x6d, 0x4f, 0x88,
            0xa5, 0xcb, 0x2d, 0x5d, 0xfe, 0xc3, 0x1a, 0x27,
            0x1a, 0xdd, 0x61, 0x7f, 0x7c, 0xe5, 0x59, 0xa9
        ])
        
        #expect(cborHex == stakePoolSKey["cborHex"])
        #expect(json == stakePoolSKeyJSON)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testStakePoolVKey() async throws {
        let VK = try! StakePoolVerificationKey.fromJSON(stakePoolVKeyJSON)
        let cborHex = try VK.toCBORHex()
        let json = try VK.toJSON()
        let expectedPayload = Data([
            0x35, 0x4c, 0xe3, 0x2d, 0xa9, 0x2e, 0x71, 0x16,
            0xf6, 0xc7, 0x0e, 0x9b, 0xe9, 0x9a, 0x3a, 0x60,
            0x1d, 0x33, 0x13, 0x7d, 0x06, 0x85, 0xab, 0x5b,
            0x7e, 0x2f, 0xf5, 0xb6, 0x56, 0x98, 0x92, 0x99
        ])
        
        #expect(cborHex == stakePoolVKey["cborHex"])
        #expect(json == stakePoolVKeyJSON)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testKeyGeneration() async throws {
        let sk = try StakePoolSigningKey.generate()
        let vk: StakePoolVerificationKey = try StakePoolVerificationKey.fromSigningKey(sk)
        let kp1 = StakePoolKeyPair(
            signingKey: sk,
            verificationKey: vk
        )
        let kp2 = try StakePoolKeyPair.fromSigningKey(sk)
        #expect(kp1 == kp2)
    }
    
    @Test func testSaveLoad() async throws {
        // Get the temporary directory
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("stakePoolSigningKey.skey")
        
        let sk = try StakePoolSigningKey.generate()
        try sk.save(to: tempFileURL.path)
        let loadedSK = try StakePoolSigningKey.load(from: tempFileURL.path)
        #expect(sk == loadedSK)
        try FileManager.default.removeItem(atPath: tempFileURL.path)
    }
    
}
