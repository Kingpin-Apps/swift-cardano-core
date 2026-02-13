import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

func makeHeader() throws -> Header {
    let headerBody = try makeHeaderBody()
    let bodySignature = KESSignature(payload: Data(repeating: 0xEE, count: KES_SIGNATURE_SIZE))
    return Header(headerBody: headerBody, bodySignature: bodySignature)
}

@Suite struct HeaderTests {
    @Test func testInitialization() async throws {
        let headerBody = try makeHeaderBody()
        let bodySignature = KESSignature(payload: Data(repeating: 0xEE, count: KES_SIGNATURE_SIZE))
        let header = Header(headerBody: headerBody, bodySignature: bodySignature)

        #expect(header.headerBody == headerBody)
        #expect(header.bodySignature == bodySignature)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let header = try makeHeader()
        let primitive = try header.toPrimitive()
        let restored = try Header(from: primitive)
        #expect(restored == header)
    }

    @Test func testPrimitiveStructure() async throws {
        let header = try makeHeader()
        let primitive = try header.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        #expect(elements.count == 2)

        // headerBody (list with 10 elements)
        guard case let .list(headerBodyElements) = elements[0] else {
            Issue.record("Expected .list for headerBody")
            return
        }
        #expect(headerBodyElements.count == 10)

        // bodySignature (bytes of 448)
        guard case let .bytes(sigData) = elements[1] else {
            Issue.record("Expected .bytes for bodySignature")
            return
        }
        #expect(sigData.count == KES_SIGNATURE_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let header = try makeHeader()
        try checkTwoWayCBOR(serializable: header)
    }

    @Test func testJSONRoundTrip() async throws {
        let header = try makeHeader()
        let dict = try header.toDict()
        let restored = try Header.fromDict(dict)
        #expect(restored == header)
    }

    @Test func testEquality() async throws {
        let header1 = try makeHeader()
        let header2 = try makeHeader()
        #expect(header1 == header2)

        // Different body signature
        let headerBody = try makeHeaderBody()
        let differentSig = KESSignature(payload: Data(repeating: 0xFF, count: KES_SIGNATURE_SIZE))
        let header3 = Header(headerBody: headerBody, bodySignature: differentSig)
        #expect(header1 != header3)
    }

    @Test func testHeaderWithNilPrevHash() async throws {
        let headerBody = try makeHeaderBody(prevHash: nil)
        let bodySignature = KESSignature(payload: Data(repeating: 0xEE, count: KES_SIGNATURE_SIZE))
        let header = Header(headerBody: headerBody, bodySignature: bodySignature)

        try checkTwoWayCBOR(serializable: header)
    }
}
