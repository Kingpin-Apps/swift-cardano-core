import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - IPv4Address Test Suite
struct IPv4AddressTests {
    @Test func testEncodingDecoding() async throws {
        let address = IPv4Address("192.168.0.1")
        
        let encodedJSONData = try JSONEncoder().encode(address)
        let jsonDecodedAddress = try JSONDecoder().decode(IPv4Address.self, from: encodedJSONData)
        
        let encodedCBORData = try CBOREncoder().encode(address)
        let cborDecodedAddress = try CBORDecoder().decode(IPv4Address.self, from: encodedCBORData)
        
        #expect(try address!.toPrimitive() == .bytes(Data([0xC0, 0xA8, 0x00, 0x01])))
        #expect(jsonDecodedAddress == address)
        #expect(cborDecodedAddress == address)
    }
    
    @Test func testInvalidDecoding() async throws {
        let json = "\"invalid_ip\"".data(using: .utf8)!
        
        #expect(throws: CardanoCoreError.self) {
            _ = try JSONDecoder().decode(IPv4Address.self, from: json)
        }
    }
}

// MARK: - IPv6Address Test Suite
struct IPv6AddressTests {
    @Test func testIPv6AddressCreation() async throws {
        // Test the problematic address from the original test
        let testAddress = "2001:db8::ff00:42:8329"
        
        // Test normalization first
        do {
            let normalized = try IPv6Address.normalizeIPv6(testAddress)
            #expect(!normalized.isEmpty)
        } catch {
            Issue.record("Normalization failed for \(testAddress): \(error)")
            return
        }
        
        let address = IPv6Address(testAddress)
        #expect(address != nil, "IPv6Address should be created successfully")
        
        // Expected should be: 2001:db8:0:0:0:ff00:42:8329
        let expected = [0x2001, 0xdb8, 0x0, 0x0, 0x0, 0xff00, 0x42, 0x8329]
        #expect(
            address!.address == expected.map { String(format: "%x", $0) }.joined(separator: ":"))
    }
    
    @Test func testEncodingDecoding() async throws {
        // Use a simpler address first to test encoding
        let address = IPv6Address("::1")
        guard let address = address else {
            throw CardanoCoreError.valueError("Failed to create IPv6Address")
        }
        
        let encodedJSONData = try JSONEncoder().encode(address)
        let jsonDecodedAddress = try JSONDecoder().decode(IPv6Address.self, from: encodedJSONData)
        
        let encodedCBORData = try CBOREncoder().encode(address)
        let cborDecodedAddress = try CBORDecoder().decode(IPv6Address.self, from: encodedCBORData)
        
        #expect(try address.toPrimitive() == .bytes(Data([
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
        ])))
        #expect(jsonDecodedAddress == address)
        #expect(cborDecodedAddress == address)
    }
    
    @Test func testInvalidDecoding() async throws {
        let json = "\"invalid_ip\"".data(using: .utf8)!
        
        #expect(throws: CardanoCoreError.self) {
            _ = try JSONDecoder().decode(IPv6Address.self, from: json)
        }
    }
}
