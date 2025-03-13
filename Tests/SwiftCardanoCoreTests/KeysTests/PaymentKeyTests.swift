import Foundation
import Testing
import SwiftNcal
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Sample JSON Keys
let paymentSKey = [
    "type": "GenesisUTxOSigningKey_ed25519",
    "description": "Genesis Initial UTxO Signing Key",
    "cborHex": "5820093be5cd3987d0c9fd8854ef908f7746b69e2d73320db6dc0f780d81585b84c2"
]

let paymentVKey = [
    "type": "GenesisUTxOVerificationKey_ed25519",
    "description": "Genesis Initial UTxO Verification Key",
    "cborHex": "58208be8339e9f3addfa6810d59e2f072f85e64d4c024c087e0d24f8317c6544f62f"
]
let extendedPaymentSKey = [
    "type": "PaymentExtendedSigningKeyShelley_ed25519_bip32",
    "description": "Genesis Initial UTxO Signing Key",
    "cborHex": "5820093be5cd3987d0c9fd8854ef908f7746b69e2d73320db6dc0f780d81585b84c2"
]

let extendedPaymentVKey = [
    "type": "GenesisUTxOVerificationKey_ed25519",
    "description": "Genesis Initial UTxO Verification Key",
    "cborHex": "58208be8339e9f3addfa6810d59e2f072f85e64d4c024c087e0d24f8317c6544f62f"
]


// MARK: - Test Suite
@Suite struct PaymentKeyTests {
    let paymentSKeyJSON = """
    {
        "type": "\(paymentSKey["type"]!)",
        "description": "\(paymentSKey["description"]!)",
        "cborHex": "\(paymentSKey["cborHex"]!)"
    }
    """
    let paymentVKeyJSON = """
    {
        "type": "\(paymentVKey["type"]!)",
        "description": "\(paymentVKey["description"]!)",
        "cborHex": "\(paymentVKey["cborHex"]!)"
    }
    """
    
    
    @Test func testPaymentSigningKey() async throws {
        let SK = try! PaymentSigningKey.fromJSON(paymentSKeyJSON)
        let cborData = try CBOREncoder().encode(SK)
        let cborHex = cborData.toHex
        let json = try SK.toJSON()
        let expectedPayload = Data([
            0x09, 0x3b, 0xe5, 0xcd, 0x39, 0x87, 0xd0, 0xc9,
            0xfd, 0x88, 0x54, 0xef, 0x90, 0x8f, 0x77, 0x46,
            0xb6, 0x9e, 0x2d, 0x73, 0x32, 0x0d, 0xb6, 0xdc,
            0x0f, 0x78, 0x0d, 0x81, 0x58, 0x5b, 0x84, 0xc2
        ])
        
        #expect(cborHex == paymentSKey["cborHex"])
        #expect(json == paymentSKeyJSON)
        #expect(SK.payload == expectedPayload)
    }
    
    @Test func testPaymentVKey() async throws {
        let VK = try! PaymentVerificationKey.fromJSON(paymentVKeyJSON)
        let cborData = try CBOREncoder().encode(VK)
        let cborHex = cborData.toHex
        let json = try VK.toJSON()
        let expectedPayload = Data([
            0x8b, 0xe8, 0x33, 0x9e, 0x9f, 0x3a, 0xdd, 0xfa,
            0x68, 0x10, 0xd5, 0x9e, 0x2f, 0x07, 0x2f, 0x85,
            0xe6, 0x4d, 0x4c, 0x02, 0x4c, 0x08, 0x7e, 0x0d,
            0x24, 0xf8, 0x31, 0x7c, 0x65, 0x44, 0xf6, 0x2f
        ])
        
        #expect(cborHex == paymentVKey["cborHex"])
        #expect(json == paymentVKeyJSON)
        #expect(VK.payload == expectedPayload)
    }
    
    @Test func testKeyGeneration() async throws {
        let sk = try PaymentSigningKey.generate()
        let vk: PaymentVerificationKey = try PaymentVerificationKey.fromSigningKey(sk)
        let kp1 = PaymentKeyPair(
            signingKey: sk,
            verificationKey: vk
        )
        let kp2 = try PaymentKeyPair.fromSigningKey(sk)
        #expect(kp1 == kp2)
    }
    
    @Test func testSaveLoad() async throws {
        // Get the temporary directory
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("paymentSigningKey.skey")
        
        let sk = try PaymentSigningKey.generate()
        try sk.save(to: tempFileURL.path)
        let loadedSK = try PaymentSigningKey.load(from: tempFileURL.path)
        #expect(sk == loadedSK)
        try FileManager.default.removeItem(atPath: tempFileURL.path)
    }
    
}

@Suite struct PaymentExtendedKeyTests {
    
    @Test func testPaymentVKey() async throws {
        let VK = extendedPaymentVerificationKey!
        
        #expect(VK != nil)
    }
    
    @Test func testPaymentSKey() async throws {
        let SK = extendedPaymentSigningKey!
        
        let extendedVkey: PaymentExtendedVerificationKey = SK.toVerificationKey()
        let vkey: PaymentVerificationKey = extendedVkey.toNonExtended()
        
        #expect(SK != nil)
        #expect(extendedVkey != nil)
        #expect(vkey != nil)
    }
}
