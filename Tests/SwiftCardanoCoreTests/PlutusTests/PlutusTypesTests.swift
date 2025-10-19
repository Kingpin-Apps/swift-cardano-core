import Foundation
import Testing
import OrderedCollections
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite("Datum Tests")
struct DatumTests {
    @Test("Test Datum with Unit")
    func testDatumUnit() async throws {
        let unit = SwiftCardanoCore.Unit()
        let datum: Datum = .plutusData(try unit.toPlutusData())
        
        let encoder = CBOREncoder()
        
        let encoded = try encoder.encode([datum])
        
        let hex = encoded.hexEncodedString()
        
        #expect(hex == "81d87980")
    }
}
