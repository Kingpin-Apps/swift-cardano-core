import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

func makeOperationalCert() throws -> OperationalCert {
    let hotVKey = KESVKey(payload: Data(repeating: 0x01, count: KES_VKEY_SIZE))
    let sigma = Data(repeating: 0x03, count: OperationalCert.SIGMA_SIZE)
    return try OperationalCert(
        hotVKey: hotVKey,
        sequenceNumber: 42,
        kesPeriod: 100,
        sigma: sigma
    )
}

@Suite struct OperationalCertTests {
    let hotVKey = KESVKey(payload: Data(repeating: 0x01, count: KES_VKEY_SIZE))
    let sigma = Data(repeating: 0x03, count: OperationalCert.SIGMA_SIZE)

    @Test func testInitialization() async throws {
        let cert = try OperationalCert(
            hotVKey: hotVKey,
            sequenceNumber: 42,
            kesPeriod: 100,
            sigma: sigma
        )
        #expect(cert.hotVKey == hotVKey)
        #expect(cert.sequenceNumber == 42)
        #expect(cert.kesPeriod == 100)
        #expect(cert.sigma == sigma)
    }

    @Test func testInvalidSigmaSize() async throws {
        let shortSigma = Data(repeating: 0x03, count: 63)
        #expect(throws: (any Error).self) {
            try OperationalCert(
                hotVKey: hotVKey,
                sequenceNumber: 42,
                kesPeriod: 100,
                sigma: shortSigma
            )
        }

        let longSigma = Data(repeating: 0x03, count: 65)
        #expect(throws: (any Error).self) {
            try OperationalCert(
                hotVKey: hotVKey,
                sequenceNumber: 42,
                kesPeriod: 100,
                sigma: longSigma
            )
        }
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let cert = try makeOperationalCert()
        let primitive = try cert.toPrimitive()
        let restored = try OperationalCert(from: primitive)
        #expect(restored == cert)
    }

    @Test func testPrimitiveStructure() async throws {
        let cert = try makeOperationalCert()
        let primitive = try cert.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        #expect(elements.count == 4)

        // hotVKey (bytes)
        guard case .bytes = elements[0] else {
            Issue.record("Expected .bytes for hotVKey")
            return
        }

        // sequenceNumber (uint)
        guard case let .uint(seq) = elements[1] else {
            Issue.record("Expected .uint for sequenceNumber")
            return
        }
        #expect(seq == 42)

        // kesPeriod (uint)
        guard case let .uint(period) = elements[2] else {
            Issue.record("Expected .uint for kesPeriod")
            return
        }
        #expect(period == 100)

        // sigma (bytes)
        guard case let .bytes(sigData) = elements[3] else {
            Issue.record("Expected .bytes for sigma")
            return
        }
        #expect(sigData.count == OperationalCert.SIGMA_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let cert = try makeOperationalCert()
        try checkTwoWayCBOR(serializable: cert)
    }

    @Test func testJSONRoundTrip() async throws {
        let cert = try makeOperationalCert()
        let dict = try cert.toDict()
        let restored = try OperationalCert.fromDict(dict)
        #expect(restored == cert)
    }

    @Test func testEquality() async throws {
        let cert1 = try makeOperationalCert()
        let cert2 = try makeOperationalCert()
        #expect(cert1 == cert2)

        let differentCert = try OperationalCert(
            hotVKey: hotVKey,
            sequenceNumber: 99,
            kesPeriod: 100,
            sigma: sigma
        )
        #expect(cert1 != differentCert)
    }
}
