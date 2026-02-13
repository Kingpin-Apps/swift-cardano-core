import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct VRFCertTests {
    let validOutput = Data(repeating: 0xAB, count: 32)
    let validProof = Data(repeating: 0xCD, count: VRFCert.PROOF_SIZE)

    @Test func testInitialization() async throws {
        let cert = try VRFCert(output: validOutput, proof: validProof)
        #expect(cert.output == validOutput)
        #expect(cert.proof == validProof)
        #expect(cert.proof.count == VRFCert.PROOF_SIZE)
    }

    @Test func testInvalidProofSize() async throws {
        let shortProof = Data(repeating: 0xCD, count: 79)
        #expect(throws: (any Error).self) {
            try VRFCert(output: validOutput, proof: shortProof)
        }

        let longProof = Data(repeating: 0xCD, count: 81)
        #expect(throws: (any Error).self) {
            try VRFCert(output: validOutput, proof: longProof)
        }
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let cert = try VRFCert(output: validOutput, proof: validProof)
        let primitive = try cert.toPrimitive()
        let restored = try VRFCert(from: primitive)
        #expect(restored == cert)
    }

    @Test func testPrimitiveStructure() async throws {
        let cert = try VRFCert(output: validOutput, proof: validProof)
        let primitive = try cert.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        #expect(elements.count == 2)

        guard case let .bytes(outputData) = elements[0] else {
            Issue.record("Expected .bytes for output")
            return
        }
        #expect(outputData == validOutput)

        guard case let .bytes(proofData) = elements[1] else {
            Issue.record("Expected .bytes for proof")
            return
        }
        #expect(proofData.count == VRFCert.PROOF_SIZE)
    }

    @Test func testCBORRoundTrip() async throws {
        let cert = try VRFCert(output: validOutput, proof: validProof)
        try checkTwoWayCBOR(serializable: cert)
    }

    @Test func testJSONRoundTrip() async throws {
        let cert = try VRFCert(output: validOutput, proof: validProof)
        let dict = try cert.toDict()
        let restored = try VRFCert.fromDict(dict)
        #expect(restored == cert)
    }

    @Test func testEquality() async throws {
        let cert1 = try VRFCert(output: validOutput, proof: validProof)
        let cert2 = try VRFCert(output: validOutput, proof: validProof)
        #expect(cert1 == cert2)

        let differentOutput = Data(repeating: 0xFF, count: 32)
        let cert3 = try VRFCert(output: differentOutput, proof: validProof)
        #expect(cert1 != cert3)
    }
}
