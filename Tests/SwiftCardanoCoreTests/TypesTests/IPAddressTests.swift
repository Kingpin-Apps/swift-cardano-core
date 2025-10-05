import Testing
import Foundation
@testable import SwiftCardanoCore

// MARK: - IPv4Address Test Suite
struct IPv4AddressTests {
    @Test func testEncodingDecoding() async throws {
        let address = IPv4Address("192.168.1.1")
        
        let encodedData = try JSONEncoder().encode(address)
        _ = String(data: encodedData, encoding: .utf8) ?? "invalid"
        
        let decodedAddress = try JSONDecoder().decode(IPv4Address.self, from: encodedData)
        
        #expect(decodedAddress == address)
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
            let normalized = try IPv6Address.debugNormalizeIPv6(testAddress)
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
        let address = IPv6Address("2001:0db8:0000:0000:ff00:0042:8329:0000")
        guard let address = address else {
            throw CardanoCoreError.valueError("Failed to create IPv6Address")
        }
        
        let encodedData = try JSONEncoder().encode(address)
        let decodedAddress = try JSONDecoder().decode(IPv6Address.self, from: encodedData)
        
        #expect(decodedAddress == address)
    }
    
    @Test func testInvalidDecoding() async throws {
        let json = "\"invalid_ip\"".data(using: .utf8)!
        
        #expect(throws: CardanoCoreError.self) {
            _ = try JSONDecoder().decode(IPv6Address.self, from: json)
        }
    }
}
