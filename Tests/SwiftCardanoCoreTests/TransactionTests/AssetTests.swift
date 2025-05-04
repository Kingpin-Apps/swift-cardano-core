import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("AssetName Tests")
struct AssetNameTests {
    @Test("AssetName initialization")
    func testInitialization() throws {
        let assetName = try AssetName(payload: Data([0x4D, 0x59, 0x5F, 0x4E, 0x46, 0x54, 0x5F, 0x31]))
        
        #expect(assetName != nil)
        #expect(assetName.description == "AssetName(MY_NFT_1)")
    }
    
    @Test("Asset initialization from primitive")
    func testInitializationFromPrimitive() throws {
        let assetName1 = AssetName(from: "MY_NFT_1")
        let assetName2 = AssetName(from: "MY_NFT_1".data(using: .utf8)!.toHex)
        
        #expect(assetName1 != nil)
        #expect(assetName1.description == "AssetName(MY_NFT_1)")
        #expect(assetName2 != nil)
        #expect(assetName2.description == "AssetName(MY_NFT_1)")
    }
}

@Suite("Asset Tests")
struct AssetTests {
    
    @Test("Asset initialization should create empty asset")
    func testEmptyAssetInitialization() throws {
        let asset = Asset([:])
        #expect(asset.data.isEmpty)
        #expect(asset == Asset.zero)
    }
    
    @Test("Asset initialization")
    func testInitialization() throws {
        let assetName = try AssetName(payload: Data([0x4D, 0x59, 0x5F, 0x4E, 0x46, 0x54, 0x5F, 0x31]))
        let asset = Asset([assetName:100])
        
        #expect(asset != nil)
        #expect(asset[assetName] == 100)
    }
    
    @Test("Asset initialization from primitive")
    func testInitializationFromPrimitive() throws {
        let asset = try Asset(from: .dict([.string("MY_NFT_1"):.int(100)]))
        
        #expect(asset != nil)
        #expect(asset.count == 1)
    }
    
    @Test("Asset addition should combine values correctly")
    func testAssetAddition() throws {
        let assetName1 = try AssetName(payload: Data([0x4D, 0x59, 0x5F, 0x4E, 0x46, 0x54, 0x5F, 0x31]))
        let assetName2 = AssetName(from: "MY_NFT_2")
        
        var asset1 = Asset([:])
        asset1[assetName1] = 10
        
        var asset2 = Asset([:])
        asset2[assetName1] = 5
        asset2[assetName2] = 15
        
        let combined = asset1 + asset2
        
        #expect(combined[assetName1] == 15)
        #expect(combined[assetName2] == 15)
    }
    
    @Test("Asset subtraction should work correctly")
    func testAssetSubtraction() throws {
        let assetName = AssetName(from: "MY_NFT_1")
        
        var asset1 = Asset([:])
        asset1[assetName] = 10
        
        var asset2 = Asset([:])
        asset2[assetName] = 3
        
        let result = asset1 - asset2
        
        #expect(result[assetName] == 7)
    }
    
    @Test("Asset should remove zero value entries")
    func testZeroValueRemoval() throws {
        let assetName = AssetName(from: "MY_NFT_1")
        
        var asset1 = Asset([:])
        asset1[assetName] = 5
        
        var asset2 = Asset([:])
        asset2[assetName] = 5
        
        let result = asset1 - asset2
        
        #expect(result.data.isEmpty)
        #expect(result == Asset.zero)
    }
    
    @Test("Asset comparison should work correctly")
    func testAssetComparison() throws {
        let assetName = try AssetName(payload: Data([0x01]))
        
        var asset1 = Asset([:])
        asset1[assetName] = 10
        
        var asset2 = Asset([:])
        asset2[assetName] = 5
        
        #expect(asset2 < asset1)
    }
    
    @Test("Asset should handle multiple operations")
    func testMultipleOperations() throws {
        let assetName1 = try AssetName(payload: Data([0x01]))
        let assetName2 = try AssetName(payload: Data([0x02]))
        
        var asset1 = Asset([:])
        asset1[assetName1] = 10
        asset1[assetName2] = 20
        
        var asset2 = Asset([:])
        asset2[assetName1] = 5
        asset2[assetName2] = 10
        
        let result = asset1 - asset2
        
        #expect(result[assetName1] == 5)
        #expect(result[assetName2] == 10)
        
        let finalResult = result + asset2
        
        #expect(finalResult == asset1)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let asset = try Asset(from: .dict([.string("MY_NFT_1"):.int(100)]))
        
        let encodedData = try CBOREncoder().encode(asset)
        let decodedInput = try CBORDecoder().decode(
            Asset.self,
            from: encodedData
        )
        
        #expect(asset == decodedInput)
    }
}
