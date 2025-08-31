import Testing
import PotentCBOR
@testable import SwiftCardanoCore


@Suite struct UnitIntervalTests {
    
    @Test func testInitialization() async throws {
        let numerator: UInt = 1
        let denominator: UInt = 100
        
        let unitInterval = UnitInterval(
            numerator: numerator,
            denominator: denominator
        )
        
        #expect(unitInterval.numerator == numerator)
        #expect(unitInterval.denominator == denominator)
    }
    
    @Test func testEncodingDecodingCBOR() async throws {
        let testCBORHex = "d81e82011864"
        let numerator: UInt = 1
        let denominator: UInt = 100
        
        let unitInterval = UnitInterval(
            numerator: numerator,
            denominator: denominator
        )
        
        let encodedCBOR = try CBOREncoder().encode(unitInterval)
        let decodedCBOR = try CBORDecoder().decode(
            UnitInterval.self,
            from: encodedCBOR
        )
        
        #expect(decodedCBOR == unitInterval)
        #expect(UnitInterval.tag == 30)
        #expect(testCBORHex == encodedCBOR.toHex)
    }
}

