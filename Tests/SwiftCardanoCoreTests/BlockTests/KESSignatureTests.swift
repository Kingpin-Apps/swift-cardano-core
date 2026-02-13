import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct KESSignatureTests {
    @Test func testValidPayload() async throws {
        let payload = Data(repeating: 0x01, count: KES_SIGNATURE_SIZE)
        let sig = KESSignature(payload: payload)
        #expect(sig.payload == payload)
        #expect(sig.payload.count == KES_SIGNATURE_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let payload = Data(repeating: 0x02, count: KES_SIGNATURE_SIZE)
        let sig = KESSignature(payload: payload)
        try checkTwoWayCBOR(serializable: sig)
    }

    @Test func testCBOREncodeDecode() async throws {
        let payload = Data(repeating: 0x03, count: KES_SIGNATURE_SIZE)
        let sig = KESSignature(payload: payload)
        let cborData = try CBOREncoder().encode(sig)
        let decoded = try CBORDecoder().decode(KESSignature.self, from: cborData)
        #expect(decoded.payload == sig.payload)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let payload = Data(repeating: 0x04, count: KES_SIGNATURE_SIZE)
        let sig = KESSignature(payload: payload)
        let primitive = sig.toPrimitive()

        guard case let .bytes(data) = primitive else {
            Issue.record("Expected .bytes primitive")
            return
        }
        #expect(data == payload)

        let restored = try KESSignature(from: primitive)
        #expect(restored == sig)
    }
}

@Suite struct KESVKeyTests {
    @Test func testValidPayload() async throws {
        let payload = Data(repeating: 0x01, count: KES_VKEY_SIZE)
        let vkey = KESVKey(payload: payload)
        #expect(vkey.payload == payload)
        #expect(vkey.payload.count == KES_VKEY_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let payload = Data(repeating: 0x02, count: KES_VKEY_SIZE)
        let vkey = KESVKey(payload: payload)
        try checkTwoWayCBOR(serializable: vkey)
    }

    @Test func testCBOREncodeDecode() async throws {
        let payload = Data(repeating: 0x03, count: KES_VKEY_SIZE)
        let vkey = KESVKey(payload: payload)
        let cborData = try CBOREncoder().encode(vkey)
        let decoded = try CBORDecoder().decode(KESVKey.self, from: cborData)
        #expect(decoded.payload == vkey.payload)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let payload = Data(repeating: 0x04, count: KES_VKEY_SIZE)
        let vkey = KESVKey(payload: payload)
        let primitive = vkey.toPrimitive()
        let restored = try KESVKey(from: primitive)
        #expect(restored == vkey)
    }
}
