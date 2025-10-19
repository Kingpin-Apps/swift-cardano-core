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
        let multiAsset = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("assetName"): .uint(5)])]))
        let value = Value(coin: coin, multiAsset: multiAsset)
        
        #expect(value.coin == coin)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Initialize Value from primitive data")
    func testPrimitiveInitialization() throws {
        let primitive: Primitive = .list([
            .uint(1000000),
            .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])])
        ])
        let value = try Value(from: primitive)
        let multiAsset = try MultiAsset(from: .dict([
            .string("policyId"): .dict([.string("asset1"): .uint(5)])
        ]))
        #expect(value.coin == 1000000)
        #expect(value.multiAsset == multiAsset)
    }
    
    @Test("Value addition")
    func testAddition() throws {
        let multiAsset1 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(3)])]))
        
        let value1 = Value(
            coin: 1000000,
            multiAsset: multiAsset1
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: multiAsset2
        )
        
        let summedMultiAsset = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
        
        let sum = value1 + value2
        #expect(sum.coin == 3000000)
        #expect(sum.multiAsset == summedMultiAsset)
    }
    
    @Test("Value subtraction")
    func testSubtraction() throws {
        let value1 = Value(
            coin: 3000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(3)])]))
        )
        
        let difference = value1 - value2
        let differenceMultiAsset = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        
        #expect(difference.coin == 2000000)
        #expect(difference.multiAsset == differenceMultiAsset)
    }
    
    @Test("Value comparison operators")
    func testComparisons() throws {
        let value1 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        )
        let value2 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
        )
        let value3 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        )
        
        #expect(value1 < value2)
        #expect(value1 <= value2)
        #expect(value1 <= value3)
        #expect(value1 == value3)
    }
    
    @Test("Value union operation")
    func testUnion() throws {
        let multiAsset1 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(3)])]))
        let unionMultiAsset = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
        
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
        let multiAsset1 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        let multiAsset2 = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(3)])]))
        let addedMultiAsset = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
        
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
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
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
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        )
        let value2 = Value(
            coin: 1000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(5)])]))
        )
        let value3 = Value(
            coin: 2000000,
            multiAsset: try MultiAsset(from: .dict([.string("policyId"): .dict([.string("asset1"): .uint(8)])]))
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
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(1), .string("Token2"): .uint(2)])
            ])
        ]))
        let b = try Value(from: .list([
            .uint(11),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(11), .string("Token2"): .uint(22)])
            ])
        ]))
        let c = try Value(from: .list([
            .uint(11),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(11), .string("Token2"): .uint(22)]),
                scriptHash2Primitive: .orderedDict([.string("Token1"): .uint(11), .string("Token2"): .uint(22)])
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
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(10), .string("Token2"): .uint(20)])
            ])
        ]))
        let bMinusA = b - a
        #expect(bMinusA == expectedBMinusA)

        let expectedCMinusA = try Value(from: .list([
            .uint(10),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(10), .string("Token2"): .uint(20)]),
                scriptHash2Primitive: .orderedDict([.string("Token1"): .uint(11), .string("Token2"): .uint(22)])
            ])
        ]))
        #expect(c - a == expectedCMinusA)

        let expectedAPlus100 = try Value(from: .list([
            .uint(101),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(1), .string("Token2"): .uint(2)])
            ])
        ]))
        #expect(a + Value(coin: 100) == expectedAPlus100)

        let expectedAMinusC = try Value(from: .list([
            .int(-10),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .int(-10), .string("Token2"): .int(-20)]),
                scriptHash2Primitive: .orderedDict([.string("Token1"): .int(-11), .string("Token2"): .int(-22)])
            ])
        ]))
        #expect(a - c == expectedAMinusC)

        let expectedBMinusC = try Value(from: .list([
            .uint(0),
            .orderedDict([
//            scriptHash1: ["Token1": 0, "Token2": 0],
                scriptHash2Primitive: .orderedDict([.string("Token1"): .int(-11), .string("Token2"): .int(-22)])
            ])
        ]))
        #expect(b - c == expectedBMinusC)

        let result = a.union(b)
        let expectedUnion = try Value(from: .list([
            .uint(12),
            .orderedDict([
                scriptHash1Primitive: .orderedDict([.string("Token1"): .uint(12), .string("Token2"): .uint(24)])
            ])
        ]))
        #expect(result == expectedUnion)

        let d = 10000000
        let f = Value(coin: 1)
        #expect(f.coin <= d)
    }
}
