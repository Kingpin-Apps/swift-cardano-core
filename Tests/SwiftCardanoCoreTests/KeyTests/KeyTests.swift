import Foundation
import Testing
import SwiftNcal
@testable import SwiftCardanoCore

// MARK: - Sample JSON Keys
let skJson = """
{
    "type": "GenesisUTxOSigningKey_ed25519",
    "description": "Genesis Initial UTxO Signing Key",
    "cborHex": "5820093be5cd3987d0c9fd8854ef908f7746b69e2d73320db6dc0f780d81585b84c2"
}
"""

let vkJson = """
{
    "type": "GenesisUTxOVerificationKey_ed25519",
    "description": "Genesis Initial UTxO Verification Key",
    "cborHex": "58208be8339e9f3addfa6810d59e2f072f85e64d4c024c087e0d24f8317c6544f62f"
}
"""

let spSkJson = """
{
    "type": "StakePoolSigningKey_ed25519",
    "description": "StakePoolSigningKey_ed25519",
    "cborHex": "582044181bd0e6be21cea5b0751b8c6d4f88a5cb2d5dfec31a271add617f7ce559a9"
}
"""

let spVkJson = """
{
    "type": "StakePoolVerificationKey_ed25519",
    "description": "StakePoolVerificationKey_ed25519",
    "cborHex": "5820354ce32da92e7116f6c70e9be99a3a601d33137d0685ab5b7e2ff5b656989299"
}
"""

// MARK: - Test Suite
@Suite struct KeyTests {
    let SK = try! PaymentSigningKey.fromJSON(skJson)
    let VK = try! PaymentVerificationKey.fromJSON(vkJson)
    let SPSK = try! StakePoolSigningKey.fromJSON(spSkJson)
    let SPVK = try! StakePoolVerificationKey.fromJSON(spVkJson)
    
    @Test func testInit() async throws {
        let payload = Data([
            0x09, 0x3b, 0xe5, 0xcd, 0x39, 0x87, 0xd0, 0xc9,
            0xfd, 0x88, 0x54, 0xef, 0x90, 0x8f, 0x77, 0x46,
            0xb6, 0x9e, 0x2d, 0x73, 0x32, 0x0d, 0xb6, 0xdc,
            0x0f, 0x78, 0x0d, 0x81, 0x58, 0x5b, 0x84, 0xc2
        ])
        let key = Key(
            payload: payload,
            keyType: "GenesisUTxOSigningKey_ed25519",
            description: "Genesis Initial UTxO Signing Key"
        )
        
        #expect(key.payload == payload)
    }
    
    @Test func testPaymentKey() async throws {
        let expectedCBORHex = try SK.toCBORHex()
        let expectedPayload = Data([0x09, 0x3b, 0xe5, 0xcd, 0x39, 0x87, 0xd0, 0xc9, 0xfd, 0x88, 0x54, 0xef, 0x90, 0x8f, 0x77, 0x46, 0xb6, 0x9e, 0x2d, 0x73,
            0x20, 0xdb, 0x6d, 0xc0, 0xf7, 0x80, 0xd8, 0x15, 0x85, 0xb8, 0x4c, 0x2])
        let expectedVKPayload = Data([0x8b, 0xe8, 0x33, 0x9e, 0x9f, 0x3a, 0xdd, 0xfa, 0x68, 0x10, 0xd5, 0x9e, 0x2f, 0x07, 0x2f, 0x85, 0xe6, 0x4d, 0x4c])
        
        #expect(expectedCBORHex == "5820093be5cd3987d0c9fd8854ef908f7746b69e2d73320db6dc0f780d81585b84c2")
//        #expect(SK.payload == expectedPayload)
        #expect(VK.payload.prefix(expectedVKPayload.count) == expectedVKPayload)
    }
    
    @Test func testStakePoolKey() async throws {
        let expectedSPSKPayload = Data([0x44, 0x18, 0x1b, 0xd0, 0xe6, 0xbe, 0x21, 0xce, 0xa5, 0xb0, 0x75])
        let expectedSPVKPayload = Data([0x35, 0x4c, 0xe3, 0x2d, 0xa9, 0x2e, 0x71])
        
        #expect(SPSK.payload.prefix(expectedSPSKPayload.count) == expectedSPSKPayload)
        #expect(SPVK.payload.prefix(expectedSPVKPayload.count) == expectedSPVKPayload)
    }
    
//    @Test func testExtendedPaymentKey() async throws {
//        let extendedSK = try! ExtendedSigningKey.fromJSON(skJson)
//        let extendedVK = ExtendedVerificationKey.fromSigningKey(extendedSK)
//        #expect(extendedVK != nil)
//    }
//    
//    @Test func testKeyGeneration() async throws {
//        let sk = try PaymentSigningKey.generate() 
//        let vk = try PaymentVerificationKey.fromSigningKey(sk) as! PaymentVerificationKey
//        let kp1 = PaymentKeyPair(signingKey: sk, verificationKey: vk)
//        let kp2 = try PaymentKeyPair.fromSigningKey(sk)
//        #expect(kp1 == kp2)
//    }
//    
//    @Test func testStakePoolKeyGeneration() async throws {
//        let sk = try StakePoolSigningKey.generate()
//        let vk = try StakePoolVerificationKey.fromSigningKey(sk) as! StakePoolVerificationKey
//        let kp1 = StakePoolKeyPair(signingKey: sk, verificationKey: vk)
//        let kp2 = try StakePoolKeyPair.fromSigningKey(sk)
//        #expect(kp1 == kp2)
//    }
//    
//    @Test func testKeyHashUniqueness() async throws {
//        let sk = try PaymentSigningKey.generate()
//        let vk = try PaymentVerificationKey.fromSigningKey(sk) as! PaymentVerificationKey
//        
//        var skSet = Set<PaymentSigningKey>()
//        var vkSet = Set<PaymentVerificationKey>()
//        
//        for _ in 0..<2 {
//            skSet.insert(sk)
//            vkSet.insert(vk)
//        }
//        
//        #expect(skSet.count == 1)
//        #expect(vkSet.count == 1)
//    }
//    
//    @Test func testStakePoolKeyHashUniqueness() async throws {
//        let sk = try StakePoolSigningKey.generate()
//        let vk = try StakePoolVerificationKey.fromSigningKey(sk) as! StakePoolVerificationKey
//        
//        var skSet = Set<StakePoolSigningKey>()
//        var vkSet = Set<StakePoolVerificationKey>() 
//        
//        for _ in 0..<2 {
//            skSet.insert(sk)
//            vkSet.insert(vk)
//        }
//        
//        #expect(skSet.count == 1)
//        #expect(vkSet.count == 1)
//    }
}
