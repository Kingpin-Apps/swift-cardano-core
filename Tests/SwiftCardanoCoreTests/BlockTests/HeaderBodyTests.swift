import Testing
import Foundation
import CBORCodable
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

        // Babbage / Conway (Praos) wire format: 10 elements, with
        // operational_cert and protocol_version nested as arrays.
        #expect(elements.count == 10)

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

        // [8] operational_cert: [hot_vkey, sequence_number, kes_period, sigma]
        guard case let .list(cert) = elements[8], cert.count == 4,
            case .bytes = cert[0], case .uint = cert[1], case .uint = cert[2], case .bytes = cert[3]
        else {
            Issue.record("Expected a 4-element operational_cert")
            return
        }

        // [9] protocol_version: [major, minor]
        guard case let .list(version) = elements[9], version.count == 2,
            case let .uint(major) = version[0], case let .uint(minor) = version[1]
        else {
            Issue.record("Expected a 2-element protocol_version")
            return
        }
        #expect(major == 10)
        #expect(minor == 0)
    }

    @Test func testTPraosPrimitiveStructure() async throws {
        // With a nonce VRF (Shelley to Alonzo): 15 flat elements.
        var headerBody = try makeHeaderBody()
        headerBody.nonceVrf = headerBody.vrfResult
        guard case let .list(elements) = try headerBody.toPrimitive() else {
            Issue.record("Expected .list primitive")
            return
        }
        #expect(elements.count == 15)
        guard case .list = elements[5], case .list = elements[6], case .bytes = elements[9],
            case .uint(10) = elements[13], case .uint(0) = elements[14]
        else {
            Issue.record("Expected the flat TPraos layout")
            return
        }
        #expect(try HeaderBody(from: .list(elements)) == headerBody)
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
