import Testing
import Foundation
import PotentCBOR
import SwiftNcal
import SwiftKES
@testable import SwiftCardanoCore

func makeOperationalCert() throws -> OperationalCertificate {
    let hotVKey = try KESVerificationKey(payload: Data(repeating: 0x01, count: KESConstants.publicKeySize))
    let sigma = Data(repeating: 0x03, count: OperationalCertificate.SIGMA_SIZE)
    return try OperationalCertificate(
        hotVKey: hotVKey,
        sequenceNumber: 42,
        kesPeriod: 100,
        sigma: sigma
    )
}

func makeOperationalCertWithColdKey() throws -> OperationalCertificate {
    let hotVKey = try KESVerificationKey(payload: Data(repeating: 0x01, count: KESConstants.publicKeySize))
    let sigma = Data(repeating: 0x03, count: OperationalCertificate.SIGMA_SIZE)
    let coldKeyPair = try StakePoolKeyPair.generate()
    return try OperationalCertificate(
        hotVKey: hotVKey,
        sequenceNumber: 42,
        kesPeriod: 100,
        sigma: sigma,
        coldVerificationKey: coldKeyPair.verificationKey
    )
}

@Suite struct OperationalCertTests {
    func makeHotVKey() throws -> KESVerificationKey {
        return try KESVerificationKey(payload: Data(repeating: 0x01, count: KESConstants.publicKeySize))
    }
    let sigma = Data(repeating: 0x03, count: OperationalCertificate.SIGMA_SIZE)

    // MARK: - Basic Initialization Tests

    @Test("Test initialization without cold verification key")
    func testInitialization() async throws {
        let hotVKey = try makeHotVKey()
        let cert = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 42,
            kesPeriod: 100,
            sigma: sigma
        )
        #expect(cert.hotVKey == hotVKey)
        #expect(cert.sequenceNumber == 42)
        #expect(cert.kesPeriod == 100)
        #expect(cert.sigma == sigma)
        #expect(cert.coldVerificationKey == nil)
        #expect(cert._type == "NodeOperationalCertificate")
    }

    @Test("Test initialization with cold verification key")
    func testInitializationWithColdKey() async throws {
        let hotVKey = try makeHotVKey()
        let coldKeyPair = try StakePoolKeyPair.generate()
        let cert = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 5,
            kesPeriod: 200,
            sigma: sigma,
            coldVerificationKey: coldKeyPair.verificationKey
        )
        #expect(cert.hotVKey == hotVKey)
        #expect(cert.sequenceNumber == 5)
        #expect(cert.kesPeriod == 200)
        #expect(cert.sigma == sigma)
        #expect(cert.coldVerificationKey == coldKeyPair.verificationKey)
    }

    @Test("Test initialization rejects invalid sigma sizes")
    func testInvalidSigmaSize() async throws {
        let hotVKey = try makeHotVKey()
        let shortSigma = Data(repeating: 0x03, count: 63)
        #expect(throws: (any Error).self) {
            try OperationalCertificate(
                hotVKey: hotVKey,
                sequenceNumber: 42,
                kesPeriod: 100,
                sigma: shortSigma
            )
        }

        let longSigma = Data(repeating: 0x03, count: 65)
        #expect(throws: (any Error).self) {
            try OperationalCertificate(
                hotVKey: hotVKey,
                sequenceNumber: 42,
                kesPeriod: 100,
                sigma: longSigma
            )
        }
    }

    @Test("Test initialization with zero-length sigma fails")
    func testEmptySigmaFails() async throws {
        let hotVKey = try makeHotVKey()
        #expect(throws: (any Error).self) {
            try OperationalCertificate(
                hotVKey: hotVKey,
                sequenceNumber: 0,
                kesPeriod: 0,
                sigma: Data()
            )
        }
    }

    // MARK: - Payload Init Tests (TextEnvelope CBOR format)

    @Test("Test init from payload with cold verification key (text envelope format)")
    func testPayloadInit() async throws {
        let hotVKey = try makeHotVKey()
        let coldKeyPair = try StakePoolKeyPair.generate()
        let original = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 10,
            kesPeriod: 300,
            sigma: sigma,
            coldVerificationKey: coldKeyPair.verificationKey
        )

        // Reconstruct from the payload (the 2-element CBOR encoding)
        let restored = try OperationalCertificate(
            payload: original._payload,
            type: nil,
            description: nil
        )

        #expect(restored.hotVKey == original.hotVKey)
        #expect(restored.sequenceNumber == original.sequenceNumber)
        #expect(restored.kesPeriod == original.kesPeriod)
        #expect(restored.sigma == original.sigma)
        #expect(restored.coldVerificationKey == original.coldVerificationKey)
        #expect(restored._type == OperationalCertificate.TYPE)
    }

    @Test("Test init from payload preserves custom type and description")
    func testPayloadInitPreservesTypeAndDescription() async throws {
        let cert = try makeOperationalCertWithColdKey()
        let restored = try OperationalCertificate(
            payload: cert._payload,
            type: "CustomType",
            description: "CustomDescription"
        )
        #expect(restored._type == "CustomType")
        #expect(restored._description == "CustomDescription")
    }

    @Test("Test init from payload rejects invalid CBOR")
    func testPayloadInitRejectsInvalid() async throws {
        // A single-element list is not a valid text envelope payload
        let badPrimitive: Primitive = .list([.uint(42)])
        let badPayload = try CBOREncoder().encode(badPrimitive)
        #expect(throws: (any Error).self) {
            try OperationalCertificate(payload: badPayload, type: nil, description: nil)
        }
    }

    // MARK: - Primitive (on-chain 4-element) Serialization

    @Test("Test primitive round trip (4-element format)")
    func testPrimitiveRoundTrip() async throws {
        let cert = try makeOperationalCert()
        let primitive = try cert.toPrimitive()
        let restored = try OperationalCertificate(from: primitive)
        #expect(restored == cert)
    }

    @Test("Test primitive structure is 4-element CBOR array")
    func testPrimitiveStructure() async throws {
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
        #expect(sigData.count == OperationalCertificate.SIGMA_SIZE)
    }

    @Test("Test init from primitive rejects non-list")
    func testPrimitiveInitRejectsNonList() async throws {
        #expect(throws: (any Error).self) {
            try OperationalCertificate(from: .uint(42))
        }
    }

    @Test("Test init from primitive rejects wrong element count")
    func testPrimitiveInitRejectsWrongCount() async throws {
        let bad = Primitive.list([.bytes(Data(repeating: 0x01, count: 32))])
        #expect(throws: (any Error).self) {
            try OperationalCertificate(from: bad)
        }
    }

    // MARK: - Primitive (text envelope 2-element) Deserialization

    @Test("Test init from 2-element text envelope primitive")
    func testPrimitiveInitTwoElementFormat() async throws {
        let hotVKey = try makeHotVKey()
        let coldKeyPair = try StakePoolKeyPair.generate()

        let opcertBody: Primitive = .list([
            .bytes(hotVKey.payload),
            .uint(7),
            .uint(500),
            .bytes(sigma)
        ])
        let envelopePrimitive: Primitive = .list([
            opcertBody,
            .bytes(coldKeyPair.verificationKey.payload)
        ])

        let cert = try OperationalCertificate(from: envelopePrimitive)
        #expect(cert.hotVKey == hotVKey)
        #expect(cert.sequenceNumber == 7)
        #expect(cert.kesPeriod == 500)
        #expect(cert.sigma == sigma)
        #expect(cert.coldVerificationKey == coldKeyPair.verificationKey)
    }

    // MARK: - CBOR Serialization

    @Test("Test CBOR round trip")
    func testCBORRoundTrip() async throws {
        let cert = try makeOperationalCert()
        try checkTwoWayCBOR(serializable: cert)
    }

    // MARK: - JSON Serialization

    @Test("Test JSON round trip")
    func testJSONRoundTrip() async throws {
        let cert = try makeOperationalCert()
        let dict = try cert.toDict()
        let restored = try OperationalCertificate.fromDict(dict)
        #expect(restored == cert)
    }

    // MARK: - TextEnvelope Serialization

    @Test("Test TextEnvelope serialization with cold key")
    func testTextEnvelopeSerialization() async throws {
        let cert = try makeOperationalCertWithColdKey()
        let json = try cert.toTextEnvelope()
        #expect(json != nil)
        #expect(json!.contains("\"type\": \"NodeOperationalCertificate\""))
        #expect(json!.contains("\"cborHex\":"))
    }

    @Test("Test TextEnvelope round trip with cold key")
    func testTextEnvelopeRoundTrip() async throws {
        let cert = try makeOperationalCertWithColdKey()
        let json = try cert.toTextEnvelope()
        #expect(json != nil)

        let restored = try OperationalCertificate.fromTextEnvelope(json!)
        #expect(restored == cert)
        #expect(restored.coldVerificationKey == cert.coldVerificationKey)
    }

    @Test("Test TextEnvelope deserialization from cardano-cli test data")
    func testTextEnvelopeDeserializationFromTestData() async throws {
        let json = """
        {
            "type": "NodeOperationalCertificate",
            "description": "",
            "cborHex": "82845820e6af17126bc5de2404195a601da9c5242a792cb551da0485361721a08781be7e001a0001fa405840a4bf3fe0eddedd6ae8621981e6b01a9c6ebcf104ef652d3944553b41e6d2ac2390d9d9e5e13830d76e975066c42ac41627f04cd88c711d1074d6c0422785330f5820b6ee6aaf452b4e538666eb892fb82e00cf119a70499b5ca3c6d4c0a0b689af4e"
        }
        """

        let cert = try OperationalCertificate.fromTextEnvelope(json)

        // Verify parsed fields match expected values
        #expect(cert.sequenceNumber == 0)
        #expect(cert.kesPeriod == 129600)
        #expect(cert.sigma.count == OperationalCertificate.SIGMA_SIZE)
        #expect(cert.hotVKey.payload.count == KESConstants.publicKeySize)
        #expect(cert.coldVerificationKey != nil)
        #expect(cert.coldVerificationKey!.payload.toHex == "b6ee6aaf452b4e538666eb892fb82e00cf119a70499b5ca3c6d4c0a0b689af4e")
        #expect(cert._type == "NodeOperationalCertificate")
    }

    @Test("Test TextEnvelope file save and load round trip")
    func testTextEnvelopeFileSaveLoad() async throws {
        let cert = try makeOperationalCertWithColdKey()

        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("test_opcert_\(UUID().uuidString).cert").path

        // Save
        try cert.save(to: filePath)

        // Load
        let loaded = try OperationalCertificate.load(from: filePath)
        #expect(loaded == cert)
        #expect(loaded.coldVerificationKey == cert.coldVerificationKey)

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
    }

    @Test("Test save refuses to overwrite existing file by default")
    func testSaveRefusesOverwrite() async throws {
        let cert = try makeOperationalCertWithColdKey()
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("test_opcert_nooverwrite_\(UUID().uuidString).cert").path

        try cert.save(to: filePath)

        #expect(throws: (any Error).self) {
            try cert.save(to: filePath)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
    }

    // MARK: - Equatable & Hashable

    @Test("Test equality compares core fields only")
    func testEquality() async throws {
        let cert1 = try makeOperationalCert()
        let cert2 = try makeOperationalCert()
        #expect(cert1 == cert2)

        let hotVKey = try makeHotVKey()
        let differentCert = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 99,
            kesPeriod: 100,
            sigma: sigma
        )
        #expect(cert1 != differentCert)
    }

    @Test("Test equality ignores cold verification key")
    func testEqualityIgnoresColdKey() async throws {
        let hotVKey = try makeHotVKey()
        let coldKeyPair = try StakePoolKeyPair.generate()

        let certWithoutColdKey = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 1,
            kesPeriod: 50,
            sigma: sigma
        )
        let certWithColdKey = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: 1,
            kesPeriod: 50,
            sigma: sigma,
            coldVerificationKey: coldKeyPair.verificationKey
        )
        #expect(certWithoutColdKey == certWithColdKey)
    }
}

// MARK: - Issue Tests

@Suite struct OperationalCertIssueTests {

    @Test("Test issue produces valid certificate")
    func testIssueBasic() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )

        #expect(cert.hotVKey == kesKeyPair.verificationKey)
        #expect(cert.sequenceNumber == 0)
        #expect(cert.kesPeriod == 100)
        #expect(cert.sigma.count == OperationalCertificate.SIGMA_SIZE)
        #expect(cert.coldVerificationKey == coldKeyPair.verificationKey)
    }

    @Test("Test issue uses counter value as sequence number")
    func testIssueUsesCounterValue() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter(
            counterValue: 7,
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 200
        )

        #expect(cert.sequenceNumber == 7)
        #expect(cert.kesPeriod == 200)
    }

    @Test("Test issue increments counter")
    func testIssueIncrementsCounter() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        #expect(counter.counterValue == 0)

        _ = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )
        #expect(counter.counterValue == 1)

        _ = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 200
        )
        #expect(counter.counterValue == 2)
    }

    @Test("Test issue produces monotonically increasing sequence numbers")
    func testIssueSequenceNumbers() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert0 = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )
        let cert1 = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 200
        )
        let cert2 = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 300
        )

        #expect(cert0.sequenceNumber == 0)
        #expect(cert1.sequenceNumber == 1)
        #expect(cert2.sequenceNumber == 2)
    }

    @Test("Test issue sigma is a valid Ed25519 signature over the certificate body")
    func testIssueSigmaIsValid() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )

        // Reconstruct the certificate body that was signed
        let certBody: Primitive = .list([
            .bytes(kesKeyPair.verificationKey.payload),
            .uint(UInt(0)),   // sequenceNumber was 0
            .uint(UInt(100))  // kesPeriod
        ])
        let certBodyBytes = try CBOREncoder().encode(certBody)

        // Verify the sigma using the cold verification key
        // When smessage contains signature + message concatenated, verify returns the original message
        let verifyKey = try SwiftNcal.VerifyKey(key: coldKeyPair.verificationKey.payload)
        let signedMessage = cert.sigma + certBodyBytes
        let verified = try verifyKey.verify(smessage: signedMessage)
        #expect(verified == certBodyBytes)
    }

    @Test("Test issue sigma rejects wrong verification key")
    func testIssueSigmaRejectsWrongKey() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        let wrongColdKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )

        // Reconstruct the certificate body
        let certBody: Primitive = .list([
            .bytes(kesKeyPair.verificationKey.payload),
            .uint(UInt(0)),
            .uint(UInt(100))
        ])
        let certBodyBytes = try CBOREncoder().encode(certBody)

        // Verification with the wrong key should fail
        let wrongVerifyKey = try SwiftNcal.VerifyKey(key: wrongColdKeyPair.verificationKey.payload)
        let signedMessage = cert.sigma + certBodyBytes
        #expect(throws: (any Error).self) {
            _ = try wrongVerifyKey.verify(smessage: signedMessage)
        }
    }

    @Test("Test issued certificate derives correct cold verification key from signing key")
    func testIssueDerivesColdVerificationKey() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )

        // Verify the cold verification key stored on the cert matches the key pair
        #expect(cert.coldVerificationKey != nil)
        #expect(cert.coldVerificationKey == coldKeyPair.verificationKey)
    }

    @Test("Test issued certificate TextEnvelope round trip")
    func testIssueTextEnvelopeRoundTrip() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 100
        )

        // Round-trip through text envelope
        let json = try cert.toTextEnvelope()
        #expect(json != nil)

        let restored = try OperationalCertificate.fromTextEnvelope(json!)
        #expect(restored == cert)
        #expect(restored.hotVKey == cert.hotVKey)
        #expect(restored.sequenceNumber == cert.sequenceNumber)
        #expect(restored.kesPeriod == cert.kesPeriod)
        #expect(restored.sigma == cert.sigma)
        #expect(restored.coldVerificationKey == cert.coldVerificationKey)
    }

    @Test("Test issued certificate file save and load round trip")
    func testIssueFileSaveLoadRoundTrip() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 256
        )

        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("test_issue_opcert_\(UUID().uuidString).cert").path

        try cert.save(to: filePath)
        let loaded = try OperationalCertificate.load(from: filePath)

        #expect(loaded == cert)
        #expect(loaded.coldVerificationKey == coldKeyPair.verificationKey)
        #expect(loaded.sequenceNumber == 0)
        #expect(loaded.kesPeriod == 256)

        try? FileManager.default.removeItem(atPath: filePath)
    }

    @Test("Test issue with different KES periods")
    func testIssueWithDifferentKesPeriods() async throws {
        let kesKeyPair = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        for kesPeriod: UInt64 in [0, 1, 64, 129600, UInt64.max] {
            let cert = try OperationalCertificate.issue(
                kesVerificationKey: kesKeyPair.verificationKey,
                coldSigningKey: coldKeyPair.signingKey,
                operationalCertificateIssueCounter: &counter,
                kesPeriod: kesPeriod
            )
            #expect(cert.kesPeriod == kesPeriod)
        }
    }

    @Test("Test issue with different KES keys produces different sigmas")
    func testIssueDifferentKeysProduceDifferentSigmas() async throws {
        let kesKeyPair1 = try KESKeyPair.generate()
        let kesKeyPair2 = try KESKeyPair.generate()
        let coldKeyPair = try StakePoolKeyPair.generate()

        var counter1 = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )
        var counter2 = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        let cert1 = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair1.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter1,
            kesPeriod: 100
        )
        let cert2 = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair2.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter2,
            kesPeriod: 100
        )

        // Different KES vkeys mean different cert bodies, so different sigmas
        #expect(cert1.sigma != cert2.sigma)
    }
}
