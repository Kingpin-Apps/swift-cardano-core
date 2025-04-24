import Foundation
import Testing
import OrderedCollections
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite("Redeemer Tests")
struct RedeemerTests {
    
    @Test("Test Redeemer initialization")
    func testRedeemerInit() async throws {
        let plutusData = try PlutusData(fields: [])
        let exUnits = ExecutionUnits(mem: 1000, steps: 2000)
        
        let redeemer = Redeemer(
            data: plutusData,
            exUnits: exUnits
        )
        
        #expect(redeemer.data == plutusData)
        #expect(redeemer.exUnits == exUnits)
        #expect(redeemer.index == 0)
        #expect(redeemer.tag == nil)
    }
    
    @Test("Test RedeemerTag values")
    func testRedeemerTagValues() throws {
        #expect(RedeemerTag.spend.rawValue == 0)
        #expect(RedeemerTag.mint.rawValue == 1)
        #expect(RedeemerTag.cert.rawValue == 2)
        #expect(RedeemerTag.reward.rawValue == 3)
        #expect(RedeemerTag.voting.rawValue == 4)
        #expect(RedeemerTag.proposing.rawValue == 5)
    }
    
    @Test("Test Redeemer encoding and decoding")
    func testRedeemerCoding() async throws {
        let plutusData = try PlutusData(
            fields: [AnyValue.wrapped(-1)]
        )
        let exUnits = ExecutionUnits(mem: 1000, steps: 2000)
        let redeemer = Redeemer<PlutusData>(data: plutusData, exUnits: exUnits)
        redeemer.tag = .spend
        redeemer.index = 1
        
        let encoder = CBOREncoder()
        let decoder = CBORDecoder()
        
        let encoded = try encoder.encode(redeemer)
        let decoded = try decoder.decode(Redeemer<PlutusData>.self, from: encoded)
        
        #expect(decoded.tag == redeemer.tag)
        #expect(decoded.index == redeemer.index)
        #expect(decoded.data == redeemer.data)
        #expect(decoded.exUnits == redeemer.exUnits)
    }
    
    @Test("Test Redeemer with MyTest data")
    func testRedeemerWithMyTestData() async throws {
        let data = try MyTest(
            a: 123,
            b: Data("234".utf8),
            c: IndefiniteList<AnyValue>([
                .uint64(4),
                .uint64(5),
                .uint64(6)
            ]),
            d: OrderedDictionary(uniqueKeysWithValues:[
                1: AnyValue.data(Data("1".utf8)),
                2: AnyValue.data(Data("2".utf8))
            ])
        )
        let exUnits = ExecutionUnits(mem: 1_000_000, steps: 1_000_000)
        let redeemer = Redeemer(data: data, exUnits: exUnits)
        redeemer.tag = .spend

        let encoder = CBOREncoder()
        encoder.deterministic = true
        let encoded = try encoder.encode(redeemer)
        let hex = encoded.hexEncodedString()

        #expect(hex == "840000d8668218829f187b433233349f040506ffa2014131024132ff821a000f42401a000f4240")

        let decoder = CBORDecoder()
        let decoded = try decoder.decode(Redeemer<MyTest>.self, from: encoded)
        #expect(decoded.tag == redeemer.tag)
        #expect(decoded.index == redeemer.index)
        #expect(decoded.data.a == redeemer.data.a)
        #expect(decoded.data.b == redeemer.data.b)
        #expect(decoded.data.c == redeemer.data.c)
//        #expect(decoded.data.d == redeemer.data.d)
        #expect(decoded.exUnits == redeemer.exUnits)
    }

    @Test("Test Redeemer with empty IndefiniteList")
    func testRedeemerWithEmptyList() async throws {
        let data = try MyTest(
            a: 123,
            b: Data("234".utf8),
            c: IndefiniteList<AnyValue>([]),
            d: OrderedDictionary(uniqueKeysWithValues:[
                1: AnyValue.data(Data("1".utf8)),
                2: AnyValue.data(Data("2".utf8))
            ])
        )
        let exUnits = ExecutionUnits(mem: 1_000_000, steps: 1_000_000)
        let redeemer = Redeemer(data: data, exUnits: exUnits)
        redeemer.tag = .spend

        let encoder = CBOREncoder()
        encoder.deterministic = true
        let encoded = try encoder.encode(redeemer)
        let hex = encoded.hexEncodedString()

        #expect(hex == "840000d8668218829f187b433233349fffa2014131024132ff821a000f42401a000f4240")

        let decoder = CBORDecoder()
        let decoded = try decoder.decode(Redeemer<MyTest>.self, from: encoded)
        #expect(decoded.tag == redeemer.tag)
        #expect(decoded.index == redeemer.index)
        #expect(decoded.data.a == redeemer.data.a)
        #expect(decoded.data.b == redeemer.data.b)
        #expect(decoded.data.c == redeemer.data.c)
//        #expect(decoded.data.d == redeemer.data.d)
        #expect(decoded.exUnits == redeemer.exUnits)
    }
    
    
    @Test("Test Redeemers list with Unit data")
    func testRedeemersUnit() throws {
        let unit = SwiftCardanoCore.Unit()
        let redeemers: Redeemers<SwiftCardanoCore.Unit> = .list([
            Redeemer<SwiftCardanoCore.Unit>(
                tag: .spend,
                index: 0,
                data: unit,
                exUnits: ExecutionUnits(mem: 1_000_000, steps: 1_000_000)
            )
        ])
        
        let encoder = CBOREncoder()
        let encoded = try encoder.encode(redeemers)
        let hex = encoded.hexEncodedString()

        #expect(hex == "81840000d87980821a000f42401a000f4240")

    }
    
    @Test("Test RedeemerKey equality and serialization")
    func testRedeemerKey() throws {
        let key1 = RedeemerKey(tag: .spend, index: 0)
        let key2 = RedeemerKey(tag: .spend, index: 0)
        let key3 = RedeemerKey(tag: .mint, index: 1)

        #expect(key1 == key2)
        #expect(key1 != key3)

        let hash1 = key1.hashValue
        let hash2 = key2.hashValue
        let hash3 = key3.hashValue

        #expect(hash1 == hash2)
        #expect(hash1 != hash3)

        let encoded = try CBOREncoder().encode(key1)
        let decoded = try CBORDecoder().decode(RedeemerKey.self, from: encoded)
        #expect(decoded == key1)
    }

    @Test("Test RedeemerValue equality and serialization")
    func testRedeemerValue() throws {
        let data = RawPlutusData(data: .int(42))
        let exUnits = ExecutionUnits(mem: 10, steps: 20)
        let value = RedeemerValue<RawPlutusData>(data: data, exUnits: exUnits)

        #expect(value.data == data)
        #expect(value.exUnits == exUnits)

        let encoded = try CBOREncoder().encode(value)
        let decoded = try CBORDecoder().decode(RedeemerValue<RawPlutusData>.self, from: encoded)

        #expect(decoded.data == value.data)
        #expect(decoded.exUnits == value.exUnits)
    }

    @Test("Test RedeemerMap creation and serialization")
    func testRedeemerMap() throws {
        var redeemerMap = RedeemerMap<RawPlutusData>()
        let data1 = RawPlutusData(data: .int(42))
        let data2 = RawPlutusData(data: .bytes(Data("test".utf8)))
        let key1 = RedeemerKey(tag: .spend, index: 0)
        let value1 = RedeemerValue<RawPlutusData>(data: data1, exUnits: ExecutionUnits(mem: 10, steps: 20))
        let key2 = RedeemerKey(tag: .mint, index: 1)
        let value2 = RedeemerValue<RawPlutusData>(data: data2, exUnits: ExecutionUnits(mem: 30, steps: 40))

        redeemerMap[key1] = value1
        redeemerMap[key2] = value2

        #expect(redeemerMap.count == 2)
        #expect(redeemerMap[key1] == value1)
        #expect(redeemerMap[key2] == value2)

        let encoded = try CBOREncoder().encode(redeemerMap)
        let decoded = try CBORDecoder().decode(RedeemerMap<RawPlutusData>.self, from: encoded)

        #expect(decoded.count == 2)
        #expect(decoded[key1]?.data == value1.data)
        #expect(decoded[key1]?.exUnits == value1.exUnits)
        #expect(decoded[key2]?.data == value2.data)
        #expect(decoded[key2]?.exUnits == value2.exUnits)
    }

    @Test("Test empty RedeemerMap in TransactionWitnessSet serialization")
    func testEmptyMapDeserialization() throws {
        let emptyMap = RedeemerMap<Never>()
        let witness = TransactionWitnessSet<Never>(redeemers: .map(emptyMap))

        let encoded = try CBOREncoder().encode(witness)
        print("Encoded hex: \(encoded.hexEncodedString())")
        let decoded = try CBORDecoder().decode(TransactionWitnessSet<Never>.self, from: encoded)

        #expect(decoded.redeemers == .map(emptyMap))
    }
}
