import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("Value Tests")
struct ValueTests {
    
    @Test("Initialize Value with default parameters")
    func testDefaultInitialization() throws {
        let value = Value()
        #expect(value.coin == 0)
        #expect(value.multiAsset == MultiAsset([:]))
    }
    
    @Test("Initialize Value with custom parameters")
    func testCustomInitialization() throws {
        let coin = 1000000
        let multiAsset = try MultiAsset(from: ["policyId": ["assetName": 5]])
        let value = Value(coin: coin, multiAsset: multiAsset)
        
        #expect(value.coin == coin)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Initialize Value from primitive data")
    func testPrimitiveInitialization() throws {
        let primitive: [Any] = [1000000, ["policyId": ["asset1": 5]]]
        let value = try Value(from: primitive)
        let multiAsset = try MultiAsset(from: ["policyId": ["asset1": 5]])
        
        #expect(value.coin == 1000000)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Value addition")
    func testAddition() throws {
        let multiAsset1 = try MultiAsset(from: ["policy1": ["asset1": 5]])
        let multiAsset2 = try MultiAsset(from: ["policy1": ["asset1": 3]])
        
        let value1 = Value(
            coin: 1000000,
            multiAsset: multiAsset1
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: multiAsset2
        )
        
        let summedMultiAsset = try MultiAsset(from: ["policy1": ["asset1": 8]])
        
        let sum = value1 + value2
        #expect(sum.coin == 3000000)
        #expect(sum.multiAsset == summedMultiAsset)
    }
    
    @Test("Value subtraction")
    func testSubtraction() throws {
        let value1 = Value(
            coin: 3000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 8]])
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 3]])
        )
        
        let difference = value1 - value2
        let differenceMultiAsset = try MultiAsset(from: ["policy1": ["asset1": 5]])
        
        #expect(difference.coin == 2000000)
        #expect(difference.multiAsset == differenceMultiAsset)
    }
    
    @Test("Value comparison operators")
    func testComparisons() throws {
        let value1 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 5]])
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 8]])
        )
        let value3 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 5]])
        )
        
        #expect(value1 < value2)
        #expect(value1 <= value2)
        #expect(value1 <= value3)
        #expect(value1 == value3)
    }
    
    @Test("Value union operation")
    func testUnion() throws {
        let multiAsset1 = try MultiAsset(from: ["policy1": ["asset1": 5]])
        let multiAsset2 = try MultiAsset(from: ["policy1": ["asset1": 3]])
        let unionMultiAsset = try MultiAsset(from: ["policy1": ["asset1": 8]])
        
        let value1 = Value(
            coin: 1000000,
            multiAsset: multiAsset1
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: multiAsset2
        )
        
        let union = value1.union(value2)
        #expect(union.coin == 3000000)
        #expect(union.multiAsset == unionMultiAsset)
    }
    
    @Test("Value compound addition")
    func testCompoundAddition() throws {
        let multiAsset1 = try MultiAsset(from: ["policy1": ["asset1": 5]])
        let multiAsset2 = try MultiAsset(from: ["policy1": ["asset1": 3]])
        let addedMultiAsset = try MultiAsset(from: ["policy1": ["asset1": 8]])
        
        var value1 = Value(
            coin: 1000000,
            multiAsset: multiAsset1
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: multiAsset2
        )
        
        value1 += value2
        #expect(value1.coin == 3000000)
        #expect(value1.multiAsset == addedMultiAsset)
    }
    
    @Test("Value Codable conformance")
    func testCodable() throws {
        let originalValue = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 5]])
        )
        let encoder = CBOREncoder()
        let decoder = CBORDecoder()
        
        let encoded = try encoder.encode(originalValue)
        let decoded = try decoder.decode(Value.self, from: encoded)
        
        #expect(decoded == originalValue)
    }
    
    @Test("Value hash consistency")
    func testHashing() throws {
        let value1 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 5]])
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 5]])
        )
        let value3 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: ["policy1": ["asset1": 8]])
        )
        
        #expect(value1.hashValue == value2.hashValue)
        #expect(value1.hashValue != value3.hashValue)
    }
} 
