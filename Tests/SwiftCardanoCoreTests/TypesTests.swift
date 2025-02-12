import Testing
import Foundation
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite struct CBORTagTests {

    @Test func testInitialization() async throws {
        let tag: UInt64 = 24
        let value: AnyValue = "testValue"
        
        let cborTag = CBORTag(tag: tag, value: value)
        
        #expect(cborTag.tag == tag)
        #expect(cborTag.value == value)
    }
    
    @Test func testEncodingDecodingCBOR() async throws {
        let testCBORHex = "d81e82011864"
        let tag: UInt64 = 30
        let value: AnyValue = .array([
            .uint64(1), .uint64(100)
        ])
        let cborTag = CBORTag(tag: tag, value: value)
        
        let encodedCBOR = try CBOREncoder().encode(cborTag)
        let decodedCBOR = try CBORDecoder().decode(
            CBORTag.self,
            from: encodedCBOR
        )
        
        print("cbor1: \(encodedCBOR.toHex)")
        print("cbor2: \(testCBORHex)")
        
        #expect(decodedCBOR == cborTag)
        #expect(decodedCBOR.tag == 30)
        #expect(testCBORHex == encodedCBOR.toHex)
    }
}


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
        
        print("cbor1: \(encodedCBOR.toHex)")
        print("cbor2: \(testCBORHex)")
        
        #expect(decodedCBOR == unitInterval)
        #expect(UnitInterval.tag == 30)
        #expect(testCBORHex == encodedCBOR.toHex)
    }
}
