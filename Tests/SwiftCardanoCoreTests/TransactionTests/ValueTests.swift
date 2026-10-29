import Testing
import Foundation
import CBORCodable
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
        let coin: Int64 = 1000000
        let multiAsset = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "assetName").payload): .uint(5)])]))
        let value = Value(coin: coin, multiAsset: multiAsset)
        
        #expect(value.coin == coin)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Initialize Value from primitive data")
    func testPrimitiveInitialization() throws {
        let primitive: Primitive = .list([
            .uint(1000000),
            .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])])
        ])
        let value = try Value(from: primitive)
        let multiAsset = try MultiAsset(from: .dict([
            .string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])
        ]))
        #expect(value.coin == 1000000)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Value addition")
    func testAddition() throws {
        let multiAsset1 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(3)])]))
        
        let value1 = Value(
            coin: 1000000,
            multiAsset: multiAsset1
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: multiAsset2
        )
        
        let summedMultiAsset = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        
        let sum = value1 + value2
        #expect(sum.coin == 3000000)
        #expect(sum.multiAsset == summedMultiAsset)
    }
    
    @Test("Value subtraction")
    func testSubtraction() throws {
        let value1 = Value(
            coin: 3000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(3)])]))
        )
        
        let difference = value1 - value2
        let differenceMultiAsset = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        
        #expect(difference.coin == 2000000)
        #expect(difference.multiAsset == differenceMultiAsset)
    }
    
    @Test("Value comparison operators")
    func testComparisons() throws {
        let value1 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        )
        let value3 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        )
        
        #expect(value1 < value2)
        #expect(value1 <= value2)
        #expect(value1 <= value3)
        #expect(value1 == value3)
    }
    
    @Test("Value union operation")
    func testUnion() throws {
        let multiAsset1 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(3)])]))
        let unionMultiAsset = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        
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
        let multiAsset1 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(3)])]))
        let addedMultiAsset = try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        
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
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
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
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(5)])]))
        )
        let value3 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: .dict([.string("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"): .dict([.bytes(AssetName(from: "asset1").payload): .uint(8)])]))
        )
        
        #expect(value1.hashValue == value2.hashValue)
        #expect(value1.hashValue != value3.hashValue)
    }
    
    @Test("Test values")
    func testValues() throws {
        let scriptHash1Primitive: Primitive = .string(String(repeating: "1", count: 56))
        let scriptHash2Primitive: Primitive = .string(String(repeating: "2", count: 56))

        let a = try Value(from: .list([
            .uint(1),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(1), .bytes(AssetName(from: "Token2").payload): .uint(2)])
            ])
        ]))
        let b = try Value(from: .list([
            .uint(11),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(11), .bytes(AssetName(from: "Token2").payload): .uint(22)])
            ])
        ]))
        let c = try Value(from: .list([
            .uint(11),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(11), .bytes(AssetName(from: "Token2").payload): .uint(22)]),
                scriptHash2Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(11), .bytes(AssetName(from: "Token2").payload): .uint(22)])
            ])
        ]))

        #expect(a != b)
        #expect(a <= b)
        #expect(!(b <= a))

        #expect(a <= c)
        #expect(!(c <= a))

        #expect(b <= c)
        #expect(!(c <= b))

        #expect(!(a == Value(coin: 0))) 

        let expectedBMinusA = try Value(from: .list([
            .uint(10),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(10), .bytes(AssetName(from: "Token2").payload): .uint(20)])
            ])
        ]))
        let bMinusA = b - a
        #expect(bMinusA == expectedBMinusA)

        let expectedCMinusA = try Value(from: .list([
            .uint(10),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(10), .bytes(AssetName(from: "Token2").payload): .uint(20)]),
                scriptHash2Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(11), .bytes(AssetName(from: "Token2").payload): .uint(22)])
            ])
        ]))
        #expect(c - a == expectedCMinusA)

        let expectedAPlus100 = try Value(from: .list([
            .uint(101),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(1), .bytes(AssetName(from: "Token2").payload): .uint(2)])
            ])
        ]))
        #expect(a + Value(coin: 100) == expectedAPlus100)

        // Differences are not output values, which the ledger reads as unsigned.
        let expectedAMinusC = Value(coin: -10, multiAsset: try MultiAsset(from: .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .int(-10), .bytes(AssetName(from: "Token2").payload): .int(-20)]),
                scriptHash2Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .int(-11), .bytes(AssetName(from: "Token2").payload): .int(-22)])
            ])))
        #expect(a - c == expectedAMinusC)

        // Differences are not output values, which the ledger reads as unsigned.
        let expectedBMinusC = Value(coin: 0, multiAsset: try MultiAsset(from: .orderedDict([
//            scriptHash1: ["Token1": 0, "Token2": 0],
                scriptHash2Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .int(-11), .bytes(AssetName(from: "Token2").payload): .int(-22)])
            ])))
        #expect(b - c == expectedBMinusC)

        let result = a.union(b)
        let expectedUnion = try Value(from: .list([
            .uint(12),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.bytes(AssetName(from: "Token1").payload): .uint(12), .bytes(AssetName(from: "Token2").payload): .uint(24)])
            ])
        ]))
        #expect(result == expectedUnion)

        let d = 10000000
        let f = Value(coin: 1)
        #expect(f.coin <= d)
    }
}
