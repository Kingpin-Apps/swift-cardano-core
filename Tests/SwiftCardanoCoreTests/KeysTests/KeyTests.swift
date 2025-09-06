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
    
    @Test func testVKey() async throws {
        let payload = Data([
            0x09, 0x3b, 0xe5, 0xcd, 0x39, 0x87, 0xd0, 0xc9,
            0xfd, 0x88, 0x54, 0xef, 0x90, 0x8f, 0x77, 0x46,
            0xb6, 0x9e, 0x2d, 0x73, 0x32, 0x0d, 0xb6, 0xdc,
            0x0f, 0x78, 0x0d, 0x81, 0x58, 0x5b, 0x84, 0xc2
        ])
        let key = VerificationKey(
            payload: payload,
            type: "GenesisUTxOSigningKey_ed25519",
            description: "Genesis Initial UTxO Signing Key"
        )
        
        #expect(key.payload == payload)
        #expect(key.toBytes() == payload)
    }
}
