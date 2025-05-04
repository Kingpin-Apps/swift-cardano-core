import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("MultiAsset Tests")
struct MultiAssetTests {
    
    @Test("MultiAsset initialization")
    func testInitialization() throws {
        let assetName = try AssetName(payload: Data([0x4D, 0x59, 0x5F, 0x4E, 0x46, 0x54, 0x5F, 0x31]))
        let asset = Asset([assetName:100])
        let scriptHash = ScriptHash(payload: Data([0x01, 0x02, 0x03]))
        
        let multiAsset = MultiAsset([scriptHash: asset])
        
        #expect(multiAsset[scriptHash]?.count == 1)
        #expect(multiAsset[scriptHash]?[assetName] == 100)
    }
    
    @Test("Initialize MultiAsset from primitive dictionary")
    func testInitFromPrimitive() async throws {
        let scriptHash1 = ScriptHash(payload: "policy1".toData)
        let scriptHash2 = ScriptHash(payload: "policy2".toData)
        
        let policy1 = try ScriptHash(from: .string(scriptHash1.payload.toHex))
        let policy2 = try ScriptHash(from: .string(scriptHash2.payload.toHex))
        
        let primitive: Primitive = .dict([
            .string(scriptHash1.payload.toHex): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)]),
            .string(scriptHash2.payload.toHex): .dict([.string("asset3"): .int(300)])
        ])
        
        let multiAsset = try MultiAsset(from: primitive)
        
        #expect(multiAsset[policy1]?.count == 2)
        #expect(multiAsset[policy2]?.count == 1)
    }
    
    @Test("Test addition of MultiAssets")
    func testAddition() async throws {
        let primitive1: Primitive = .dict([.string("policy1"): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)])])
        let primitive2: Primitive = .dict([.string("policy1"): .dict([.string("asset1"): .int(50), .string("asset3"): .int(300)])])
        
        let multiAsset1 = try MultiAsset(from: primitive1)
        let multiAsset2 = try MultiAsset(from: primitive2)
        
        let result = multiAsset1 + multiAsset2
        let policy1 = try ScriptHash(from: .string("policy1"))
        
        let asset1 = AssetName(from: "asset1")
        let asset2 = AssetName(from: "asset2")
        let asset3 = AssetName(from: "asset3")
        
        #expect(result[policy1]?.data[asset1] == 150)
        #expect(result[policy1]?.data[asset2] == 200)
        #expect(result[policy1]?.data[asset3] == 300)
    }
    
    @Test("Test subtraction of MultiAssets")
    func testSubtraction() async throws {
        let primitive1: Primitive = .dict([
            .string("policy1"): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)])
        ])
        let primitive2: Primitive = .dict([.string("policy1"): .dict([.string("asset1"): .int(50), .string("asset2"): .int(50)])])
        
        let multiAsset1 = try MultiAsset(from: primitive1)
        let multiAsset2 = try MultiAsset(from: primitive2)
        
        let result = multiAsset1 - multiAsset2
        let policy1 = try ScriptHash(from: .string("policy1"))
        
        let asset1 = AssetName(from: "asset1")
        let asset2 = AssetName(from: "asset2")
        
        #expect(result[policy1]?.data[asset1] == 50)
        #expect(result[policy1]?.data[asset2] == 150)
    }
    
    @Test("Test comparison operators")
    func testComparison() async throws {
        let primitive1: Primitive = .dict([
            .string("policy1"): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)])
        ])
        let primitive2: Primitive = .dict([.string("policy1"): .dict([.string("asset1"): .int(50), .string("asset2"): .int(50)])])
        
        let multiAsset1 = try MultiAsset(from: primitive1)
        let multiAsset2 = try MultiAsset(from: primitive2)
        
        #expect(multiAsset2 <= multiAsset1)
    }
    
    @Test("Test filtering MultiAsset")
    func testFilter() async throws {
        let scriptHash1 = ScriptHash(payload: "policy1".toData)
        let scriptHash2 = ScriptHash(payload: "policy2".toData)
        
        let policy1 = try ScriptHash(from: .string(scriptHash1.payload.toHex))
        let policy2 = try ScriptHash(from: .string(scriptHash2.payload.toHex))
        
        let primitive: Primitive = .dict([
            .string(scriptHash1.payload.toHex): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)]),
            .string(scriptHash2.payload.toHex): .dict([.string("asset3"): .int(300)])
        ])
        
        let multiAsset = try MultiAsset(from: primitive)
        
        // Filter assets with amount greater than 150
        let filtered = try multiAsset.filter { _, _, amount in
            amount > 150
        }
        
        let asset1 = AssetName(from: "asset1")
        let asset2 = AssetName(from: "asset2")
        let asset3 = AssetName(from: "asset3")
        
        #expect(filtered[policy1]?.data[asset1] == nil)
        #expect(filtered[policy1]?.data[asset2] == 200)
        #expect(filtered[policy2]?.data[asset3] == 300)
    }
    
    @Test("Test counting MultiAsset elements")
    func testCount() async throws {
        let scriptHash1 = ScriptHash(payload: "policy1".toData)
        let scriptHash2 = ScriptHash(payload: "policy2".toData)
        
        let primitive: Primitive = .dict([
            .string(scriptHash1.payload.toHex): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)]),
            .string(scriptHash2.payload.toHex): .dict([.string("asset3"): .int(300)])
        ])
        
        let multiAsset = try MultiAsset(from: primitive)
        
        // Count assets with amount greater than 150
        let count = try multiAsset.count { _, _, amount in
            amount > 150
        }
        
        #expect(count == 2)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let primitive: Primitive = .dict([
            .string("policy1"): .dict([.string("asset1"): .int(100), .string("asset2"): .int(200)]),
            .string("policy2"): .dict([.string("asset3"): .int(300)])
        ])
        
        
        let multiAsset = try MultiAsset(from: primitive)
        
        let encodedData = try CBOREncoder().encode(multiAsset)
        let decodedInput = try CBORDecoder().decode(
            MultiAsset.self,
            from: encodedData
        )
        
        #expect(multiAsset == decodedInput)
    }
}
