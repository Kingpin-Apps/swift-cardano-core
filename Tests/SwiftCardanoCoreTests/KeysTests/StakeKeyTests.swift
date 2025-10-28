import Foundation
import Testing
import SwiftNcal
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Sample JSON Keys
let stakeSKey = [
    "type": "StakeSigningKeyShelley_ed25519",
    "description": "Stake Signing Key",
    "cborHex": "5820ff3a330df8859e4e5f42a97fcaee73f6a00d0cf864f4bca902bd106d423f02c0"
]

let stakeVKey = [
    "type": "StakeVerificationKeyShelley_ed25519",
    "description": "Stake Verification Key",
    "cborHex": "58205edaa384c658c2bd8945ae389edac0a5bd452d0cfd5d1245e3ecd540030d1e3c"
]

// MARK: - Test Suite
@Suite struct StakeKeyTests {
    let stakeSKeyJSON = """
    {
        "type": "\(stakeSKey["type"]!)",
        "description": "\(stakeSKey["description"]!)",
        "cborHex": "\(stakeSKey["cborHex"]!)"
    }
    """
    
    let stakeVKeyJSON = """
    {
        "type": "\(stakeVKey["type"]!)",
        "description": "\(stakeVKey["description"]!)",
        "cborHex": "\(stakeVKey["cborHex"]!)"
    }
    """
    
    @Test func testStakeSigningKey() async throws {
        let SK = try! StakeSigningKey.fromTextEnvelope(stakeSKeyJSON)
        let cborData = try CBOREncoder().encode(SK)
        let cborHex = cborData.toHex
        let json = try SK.toTextEnvelope()
        let expectedPayload = Data([
            0xff, 0x3a, 0x33, 0x0d, 0xf8, 0x85, 0x9e, 0x4e,
            0x5f, 0x42, 0xa9, 0x7f, 0xca, 0xee, 0x73, 0xf6,
            0xa0, 0x0d, 0x0c, 0xf8, 0x64, 0xf4, 0xbc, 0xa9,
            0x02, 0xbd, 0x10, 0x6d, 0x42, 0x3f, 0x02, 0xc0
        ])
        
        #expect(cborHex == stakeSKey["cborHex"])
        #expect(json == stakeSKeyJSON)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testStakeVerificationKey() async throws {
        let VK = try! StakeVerificationKey.fromTextEnvelope(stakeVKeyJSON)
//        let VK = stakeVerificationKey
        let cborData = try CBOREncoder().encode(VK)
        let cborHex = cborData.toHex
        let json = try VK.toTextEnvelope()
        let expectedPayload = Data([
            0x5e, 0xda, 0xa3, 0x84, 0xc6, 0x58, 0xc2, 0xbd,
            0x89, 0x45, 0xae, 0x38, 0x9e, 0xda, 0xc0, 0xa5,
            0xbd, 0x45, 0x2d, 0x0c, 0xfd, 0x5d, 0x12, 0x45,
            0xe3, 0xec, 0xd5, 0x40, 0x03, 0x0d, 0x1e, 0x3c
        ])
        
        #expect(cborHex == stakeVKey["cborHex"])
        #expect(json == stakeVKeyJSON)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testKeyPairGeneration() async throws {
        let sk = try StakeSigningKey.generate()
        let vk: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(sk)
        let kp1 = StakeKeyPair(
            signingKey: sk,
            verificationKey: vk
        )
        let kp2 = try StakeKeyPair.fromSigningKey(sk)
        #expect(kp1 == kp2)
    }
    
    @Test func testSaveLoadStakeKeys() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("stakeSigningKey.skey")
        
        let sk = try StakeSigningKey.generate()
        try sk.save(to: tempFileURL.path)
        let loadedSK = try StakeSigningKey.load(from: tempFileURL.path)
        #expect(sk == loadedSK)
        try FileManager.default.removeItem(atPath: tempFileURL.path)
    }
}
