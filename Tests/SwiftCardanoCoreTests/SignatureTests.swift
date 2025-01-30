import Testing
import Foundation

import PotentCBOR
@testable import SwiftCardanoCore

let signatureTestsArguments: Zip2Sequence<[any ConstrainedBytes.Type], [Int]> = zip([
    Signature.self
],[
    SIGNATURE_SIZE
])

@Suite struct SignatureTests {
    @Test("Test CBOR Encoding", arguments: signatureTestsArguments)
    func testToCBOR(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let payload = Data(repeating: 0, count: size)
        let keyHash = try type.init(payload: payload)
        let cborData = try CBOREncoder().encode(keyHash)
        #expect(cborData != nil, "CBOR data should not be nil")
    }
    
    @Test("Test CBOR Decoding", arguments: signatureTestsArguments)
    func testFromCBOR(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let payload = Data(repeating: 0, count: size)
        let keyHash = try type.init(payload: payload)
        let cborData = try CBOREncoder().encode(keyHash)
        
        let decodedKeyHash = try CBORDecoder().decode(type, from: cborData)
        
        #expect(
            decodedKeyHash.payload == keyHash.payload,
            "Decoded payload should match original payload"
        )
    }
    
    @Test("Test Invalid Payload", arguments: signatureTestsArguments)
    func testInvalidSizePayload(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let invalidPayload = Data(repeating: 0, count: size - 1)
        #expect(throws: Never.self) {
            let _ = try type.init(payload: invalidPayload)
        }
    }
    
    @Test("Test Valid Payload", arguments: signatureTestsArguments)
    func testValidSizePayload(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        do {
            let payload = Data(repeating: 0, count: size)
            let keyHash = try type.init(payload: payload)
            #expect(keyHash.payload.count == size, "Payload size should be \(size)")
        } catch {
            Issue.record("Error: \(error)")
        }
    }
    
}
