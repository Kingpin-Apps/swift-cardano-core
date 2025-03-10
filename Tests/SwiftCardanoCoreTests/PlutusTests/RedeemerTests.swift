import Foundation
import Testing
@testable import SwiftCardanoCore

@Suite("Redeemer Tests")
struct RedeemerTests {
    
    @Test("Test Redeemer initialization")
    func testRedeemerInit() async throws {
        let plutusData = PlutusData.boundedBytes(Data(repeating: 0x01, count: 32))
        let exUnits = ExecutionUnits(mem: 1000, steps: 2000)
        
        let redeemer = Redeemer(data: plutusData, exUnits: exUnits)
        
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
        let plutusData = PlutusData.boundedBytes(Data(repeating: 0x01, count: 32))
        let exUnits = ExecutionUnits(mem: 1000, steps: 2000)
        var redeemer = Redeemer(data: plutusData, exUnits: exUnits)
        redeemer.tag = .spend
        redeemer.index = 1
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(redeemer)
        let decoded = try decoder.decode(Redeemer.self, from: encoded)
        
        #expect(decoded.tag == redeemer.tag)
        #expect(decoded.index == redeemer.index)
        #expect(decoded.data == redeemer.data)
        #expect(decoded.exUnits == redeemer.exUnits)
    }
} 
