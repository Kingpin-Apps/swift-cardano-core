import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("RawPlutusData Tests")
struct RawPlutusDataTests {
    
    @Test("Test JSON encoding and decoding")
    func testJSONCoding() throws {
        // Create test data
        let rawDatum = RawDatum.int(42)
        let plutusData = RawPlutusData(data: rawDatum)
        
        // Test JSON encoding
        let jsonEncoder = JSONEncoder()
        let encodedData = try jsonEncoder.encode(plutusData)
        
        // Test JSON decoding
        let jsonDecoder = JSONDecoder()
        let decodedData = try jsonDecoder.decode(RawPlutusData.self, from: encodedData)
        
        #expect(decodedData == plutusData)
        #expect(decodedData.data == rawDatum)
    }
    
    @Test("Test CBOR encoding and decoding")
    func testCBORCoding() throws {
        // Create test data with different RawDatum types
        let testCases: [RawPlutusData] = [
            RawPlutusData(data: .int(42)),
            RawPlutusData(data: .bytes(Data([0x01, 0x02, 0x03]))),
        ]
        
        for original in testCases {
            // Test CBOR encoding
            let encodedData = try original.toCBORData()
            
            // Test CBOR decoding
            let decoded = try RawPlutusData.fromCBOR(data: encodedData)
            
            #expect(decoded == original)
            #expect(decoded.data == original.data)
        }
    }
    
    @Test("Test equality and hash value")
    func testEquality() {
        let data1 = RawPlutusData(data: .int(42))
        let data2 = RawPlutusData(data: .int(42))
        let data3 = RawPlutusData(data: .int(43))
        
        #expect(data1 == data2)
        #expect(data1 != data3)
        #expect(data1.hashValue == data2.hashValue)
        #expect(data1.hashValue != data3.hashValue)
    }
} 
