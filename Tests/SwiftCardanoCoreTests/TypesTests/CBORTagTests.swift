import Testing
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite struct CBORTagTests {

    @Test func testInitialization() async throws {
        let tag: UInt64 = 24
        let value: Primitive = .string("testValue")
        
        let cborTag = CBORTag(tag: tag, value: value)
        
        #expect(cborTag.tag == tag)
        #expect(cborTag.value == value)
    }
    
    @Test func testEncodingDecodingCBOR() async throws {
        let testCBORHex = "d81e82011864"
        let tag: UInt64 = 30
        let value: Primitive = .list([
            .uint(1), .uint(100)
        ])
        let cborTag = CBORTag(tag: tag, value: value)
        
        let encodedCBOR = try cborTag.toCBORData()
        let decodedCBOR = try CBORTag.fromCBOR(data: encodedCBOR)
        
        #expect(decodedCBOR == cborTag)
        #expect(decodedCBOR.tag == 30)
        #expect(testCBORHex == encodedCBOR.toHex)
    }
}
