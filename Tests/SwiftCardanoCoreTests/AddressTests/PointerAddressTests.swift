import Testing
import Foundation
@testable import SwiftCardanoCore

struct PointerAddressTests {
    
    @Test func testInitialization() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        #expect(pointerAddress.slot == 1)
        #expect(pointerAddress.txIndex == 2)
        #expect(pointerAddress.certIndex == 3)
    }
        
    @Test func testEncode() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let encodedData = pointerAddress.encode()
        #expect(encodedData == Data([0x01, 0x02, 0x03]))
        
        let largePointerAddress = PointerAddress(slot: 123456789, txIndex: 2, certIndex: 3)
        let largeEncodedData = largePointerAddress.encode()
        #expect(largeEncodedData == Data([0xba, 0xef, 0x9a, 0x15, 0x02, 0x03]))
    }
    
    @Test func testDecode() async throws {
        let data = Data([0x01, 0x02, 0x03])
        let decodedPointerAddress = try? PointerAddress.decode(data)
        #expect(decodedPointerAddress?.slot == 1)
        #expect(decodedPointerAddress?.txIndex == 2)
        #expect(decodedPointerAddress?.certIndex == 3)
        
        let largeData = Data([0xba, 0xef, 0x9a, 0x15, 0x02, 0x03])
        let largeDecodedPointerAddress = try? PointerAddress.decode(largeData)
        #expect(largeDecodedPointerAddress?.slot == 123456789)
        #expect(largeDecodedPointerAddress?.txIndex == 2)
        #expect(largeDecodedPointerAddress?.certIndex == 3)
    }
    
    @Test func testDecodeInvalidData() async throws {
        let invalidData = Data([0x01, 0x02])
        #expect(throws: CardanoCoreError.self) {
            let _ = try PointerAddress.decode(invalidData)
        }
    }
    
    @Test func testEquatable() async throws {
        let pointerAddress1 = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let pointerAddress2 = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let pointerAddress3 = PointerAddress(slot: 123456789, txIndex: 2, certIndex: 3)
        
        #expect(pointerAddress1 == pointerAddress2)
        #expect(pointerAddress1 != pointerAddress3)
    }
    
    @Test func testDescription() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        #expect(pointerAddress.description == "PointerAddress(1, 2, 3)")
    }
}

