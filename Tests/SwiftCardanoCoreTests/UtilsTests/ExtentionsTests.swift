import Testing
import Foundation
import OrderedCollections
import PotentCBOR
import Network
@testable import SwiftCardanoCore

// MARK: - IPv4Address Test Suite
struct IPv4AddressTests {
    @Test func testEncodingDecoding() async throws {
        let address = IPv4Address("192.168.1.1")!
        let encodedData = try JSONEncoder().encode(address)
        let decodedAddress = try JSONDecoder().decode(IPv4Address.self, from: encodedData)
        
        #expect(decodedAddress == address)
    }
    
    @Test func testInvalidDecoding() async throws {
        let json = "\"invalid_ip\"".data(using: .utf8)!
        
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(IPv4Address.self, from: json)
        }
    }
}

// MARK: - IPv6Address Test Suite
struct IPv6AddressTests {
    @Test func testEncodingDecoding() async throws {
        let address = IPv6Address("2001:db8::ff00:42:8329")!
        let encodedData = try JSONEncoder().encode(address)
        let decodedAddress = try JSONDecoder().decode(IPv6Address.self, from: encodedData)
        
        #expect(decodedAddress == address)
    }
    
    @Test func testInvalidDecoding() async throws {
        let json = "\"invalid_ip\"".data(using: .utf8)!
        
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(IPv6Address.self, from: json)
        }
    }
}

// MARK: - CBOR Test Suite
struct CBORTests {
    @Test func testStringEncoding() async throws {
        let value: Any = "hello"
        let cborValue = CBOR.fromAny(value)
        
        #expect(cborValue == .utf8String("hello"))
    }
    
    @Test func testIntegerEncoding() async throws {
        let value: Any = 42
        let cborValue = CBOR.fromAny(value)
        
        #expect(cborValue == .unsignedInt(42))
    }
    
    @Test func testNegativeIntegerEncoding() async throws {
        let value: Any = -5
        let cborValue = CBOR.fromAny(value)
        
        #expect(cborValue == .negativeInt(5))
    }
}

// MARK: - Data Test Suite
struct DataTests {
    @Test func testToBytesConversion() async throws {
        let data = Data([0x01, 0x02, 0x03])
        let bytes = data.toBytes
        
        #expect(bytes == [0x01, 0x02, 0x03])
    }
    
    @Test func testToHexConversion() async throws {
        let data = Data([0xAB, 0xCD, 0xEF])
        let hexString = data.toHex
        
        #expect(hexString == "abcdef")
    }
    
    @Test func testRandomBytesGeneration() async throws {
        let randomData1 = Data.randomBytes(count: 16)
        let randomData2 = Data.randomBytes(count: 16)
        
        #expect(randomData1.count == 16)
        #expect(randomData2.count == 16)
        #expect(randomData1 != randomData2)  // Highly unlikely to be the same
    }
    
    @Test func testHexStringToData() async throws {
        let hexString = "010203"
        let data = Data(hexString: hexString)
        
        #expect(data != nil)
        #expect(data!.toBytes == [0x01, 0x02, 0x03])
    }
}

// MARK: - Dictionary Test Suite
struct DictionaryTests {
    @Test func testToCBORConversion() async throws {
        let dict: [AnyHashable: Any] = ["key": "value", "number": 42]
        let cborMap = dict.mapKeysToCbor
        
        #expect(cborMap[CBOR.utf8String("key")] == CBOR.utf8String("value"))
        #expect(cborMap[CBOR.utf8String("number")] == CBOR.unsignedInt(42))
    }
}

// MARK: - String Test Suite
struct StringTests {
    @Test func testToDataConversion() async throws {
        let string = "Hello"
        let data = string.toData
        
        #expect(data == "Hello".data(using: .utf8))
    }
    
    @Test func testHexStringToData() async throws {
        let hexString = "deadbeef"
        let data = hexString.hexStringToData
        
        #expect(data.toHex == "deadbeef")
    }
    
    @Test func testInvalidHexStringToData() async throws {
        let hexString = "xyz123"
        let data = hexString.hexStringToData
        
        #expect(data.toHex != "xyz123") // Should not produce valid hex data
    }
}
