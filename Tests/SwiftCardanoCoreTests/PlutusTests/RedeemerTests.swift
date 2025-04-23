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
}
