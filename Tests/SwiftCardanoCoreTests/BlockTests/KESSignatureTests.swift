import Testing
import Foundation
import PotentCBOR
import SwiftKES
@testable import SwiftCardanoCore

@Suite struct KESSignatureTests {
    @Test func testValidPayload() async throws {
        let payload = Data(repeating: 0x01, count: KES_SIGNATURE_SIZE)
        let sig = try SwiftKES.KESSignature(depth: Sum6KES.depth, bytes: payload)
        #expect(sig.bytes == payload)
        #expect(sig.bytes.count == KES_SIGNATURE_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let payload = Data(repeating: 0x02, count: KES_SIGNATURE_SIZE)
        let sig = try SwiftKES.KESSignature(depth: Sum6KES.depth, bytes: payload)
        try checkTwoWayCBOR(serializable: sig)
    }

    @Test func testCBOREncodeDecode() async throws {
        let payload = Data(repeating: 0x03, count: KES_SIGNATURE_SIZE)
        let sig = try SwiftKES.KESSignature(depth: Sum6KES.depth, bytes: payload)
        let cborData = try CBOREncoder().encode(sig)
        let decoded = try CBORDecoder().decode(SwiftKES.KESSignature.self, from: cborData)
        #expect(decoded.bytes == sig.bytes)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let payload = Data(repeating: 0x04, count: KES_SIGNATURE_SIZE)
        let sig = try SwiftKES.KESSignature(depth: Sum6KES.depth, bytes: payload)
        let primitive = sig.toPrimitive()

        guard case let .bytes(data) = primitive else {
            Issue.record("Expected .bytes primitive")
            return
        }
        #expect(data == payload)

        let restored = try SwiftKES.KESSignature(from: primitive)
        #expect(restored == sig)
    }
}

@Suite struct KESVerificationKeyTests {
    @Test func testValidPayload() async throws {
        let payload = Data(repeating: 0x01, count: KESConstants.publicKeySize)
        let vkey = try KESVerificationKey(payload: payload)
        #expect(vkey.payload == payload)
        #expect(vkey.payload.count == KESConstants.publicKeySize)
    }

    @Test func testCBORRoundTrip() async throws {
        let payload = Data(repeating: 0x02, count: KESConstants.publicKeySize)
        let vkey = try KESVerificationKey(payload: payload)
        try checkTwoWayCBOR(serializable: vkey)
    }

    @Test func testCBOREncodeDecode() async throws {
        let payload = Data(repeating: 0x03, count: KESConstants.publicKeySize)
        let vkey = try KESVerificationKey(payload: payload)
        let cborData = try CBOREncoder().encode(vkey)
        let decoded = try CBORDecoder().decode(KESVerificationKey.self, from: cborData)
        #expect(decoded.payload == vkey.payload)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let payload = Data(repeating: 0x04, count: KESConstants.publicKeySize)
        let vkey = try KESVerificationKey(payload: payload)
        let primitive = vkey.toPrimitive()
        let restored = try KESVerificationKey(from: primitive)
        #expect(restored == vkey)
    }

    @Test func testHashGeneration() async throws {
        let payload = Data(repeating: 0x05, count: KESConstants.publicKeySize)
        let vkey = try KESVerificationKey(payload: payload)
        let hash = try vkey.hash()
        #expect(hash.payload.count == KES_KEY_HASH_SIZE)
    }
}
