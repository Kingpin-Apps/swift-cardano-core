import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

func makeHeaderBody(prevHash: BlockHeaderHash? = BlockHeaderHash(payload: Data(repeating: 0xAA, count: BLOCK_HEADER_HASH_SIZE))) throws -> HeaderBody {
    let vrfResult = try VRFCert(
        output: Data(repeating: 0x10, count: 32),
        proof: Data(repeating: 0x20, count: VRFCert.PROOF_SIZE)
    )

    let operationalCert = try makeOperationalCert()

    return HeaderBody(
        blockNumber: 12345,
        slot: 67890,
        prevHash: prevHash,
        issuerVKey: Data(repeating: 0x05, count: 32),
        vrfVKey: Data(repeating: 0x06, count: 32),
        vrfResult: vrfResult,
        blockBodySize: 1024,
        blockBodyHash: BlockBodyHash(payload: Data(repeating: 0xBB, count: BLOCK_BODY_HASH_SIZE)),
        operationalCert: operationalCert,
        protocolVersion: ProtocolVersion(major: 10, minor: 0)
    )
}

@Suite struct HeaderBodyTests {
    @Test func testInitialization() async throws {
        let headerBody = try makeHeaderBody()

        #expect(headerBody.blockNumber == 12345)
        #expect(headerBody.slot == 67890)
        #expect(headerBody.prevHash != nil)
        #expect(headerBody.issuerVKey.count == 32)
        #expect(headerBody.vrfVKey.count == 32)
        #expect(headerBody.blockBodySize == 1024)
        #expect(headerBody.protocolVersion.major == 10)
        #expect(headerBody.protocolVersion.minor == 0)
    }

    @Test func testNilPrevHash() async throws {
        let headerBody = try makeHeaderBody(prevHash: nil)
        #expect(headerBody.prevHash == nil)

        // Verify CBOR round trip with nil prevHash
        let primitive = try headerBody.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        // prevHash at index 2 should be null
        guard case .null = elements[2] else {
            Issue.record("Expected .null for nil prevHash")
            return
        }

        let restored = try HeaderBody(from: primitive)
        #expect(restored == headerBody)
        #expect(restored.prevHash == nil)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let headerBody = try makeHeaderBody()
        let primitive = try headerBody.toPrimitive()
        let restored = try HeaderBody(from: primitive)
        #expect(restored == headerBody)
    }

    @Test func testPrimitiveStructure() async throws {
        let headerBody = try makeHeaderBody()
        let primitive = try headerBody.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        // Alonzo / Babbage / Conway wire format: 14 flat elements
        // (operational_cert and protocol_version groups are inlined).
        #expect(elements.count == 14)

        // [0] blockNumber (uint)
        guard case let .uint(blockNum) = elements[0] else {
            Issue.record("Expected .uint for blockNumber")
            return
        }
        #expect(blockNum == 12345)

        // [1] slot (uint)
        guard case let .uint(slot) = elements[1] else {
            Issue.record("Expected .uint for slot")
            return
        }
        #expect(slot == 67890)

        // [2] prevHash (bytes)
        guard case .bytes = elements[2] else {
            Issue.record("Expected .bytes for prevHash")
            return
        }

        // [3] issuerVKey (bytes)
        guard case .bytes = elements[3] else {
            Issue.record("Expected .bytes for issuerVKey")
            return
        }

        // [4] vrfVKey (bytes)
        guard case .bytes = elements[4] else {
            Issue.record("Expected .bytes for vrfVKey")
            return
        }

        // [5] vrfResult (list)
        guard case .list = elements[5] else {
            Issue.record("Expected .list for vrfResult")
            return
        }

        // [6] blockBodySize (uint)
        guard case let .uint(bodySize) = elements[6] else {
            Issue.record("Expected .uint for blockBodySize")
            return
        }
        #expect(bodySize == 1024)

        // [7] blockBodyHash (bytes)
        guard case .bytes = elements[7] else {
            Issue.record("Expected .bytes for blockBodyHash")
            return
        }

        // operational_cert inlined:
        // [8] hot_vkey (bytes)
        guard case .bytes = elements[8] else {
            Issue.record("Expected .bytes for hot_vkey")
            return
        }

        // [9] sequence_number (uint)
        guard case .uint = elements[9] else {
            Issue.record("Expected .uint for sequence_number")
            return
        }

        // [10] kes_period (uint)
        guard case .uint = elements[10] else {
            Issue.record("Expected .uint for kes_period")
            return
        }

        // [11] sigma (bytes)
        guard case .bytes = elements[11] else {
            Issue.record("Expected .bytes for sigma")
            return
        }

        // protocol_version inlined:
        // [12] major (uint)
        guard case let .uint(major) = elements[12] else {
            Issue.record("Expected .uint for protocol major")
            return
        }
        #expect(major == 10)

        // [13] minor (uint)
        guard case let .uint(minor) = elements[13] else {
            Issue.record("Expected .uint for protocol minor")
            return
        }
        #expect(minor == 0)
    }

    @Test func testCBORRoundTrip() async throws {
        let headerBody = try makeHeaderBody()
        try checkTwoWayCBOR(serializable: headerBody)
    }

    @Test func testCBORRoundTripNilPrevHash() async throws {
        let headerBody = try makeHeaderBody(prevHash: nil)
        try checkTwoWayCBOR(serializable: headerBody)
    }

    @Test func testJSONRoundTrip() async throws {
        let headerBody = try makeHeaderBody()
        let dict = try headerBody.toDict()
        let restored = try HeaderBody.fromDict(dict)
        #expect(restored == headerBody)
    }

    @Test func testEquality() async throws {
        let hb1 = try makeHeaderBody()
        let hb2 = try makeHeaderBody()
        #expect(hb1 == hb2)

        let hb3 = try makeHeaderBody(prevHash: nil)
        #expect(hb1 != hb3)
    }
}
