import Testing
import Foundation
import CBORCodable
import SwiftNaCl
import SwiftKES
@testable import SwiftCardanoCore

private let skeyHex = "5820" + String(repeating: "ab", count: 32)

private func envelopeDict(_ json: String) throws -> [String: String] {
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
    return try #require(object as? [String: String])
}

private func testBody(fee: Coin = 200_000) -> TransactionBody {
    TransactionBody(
        inputs: .list([TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)]),
        outputs: [TransactionOutput(
            address: try! Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"),
            amount: Value(coin: 2_000_000))],
        fee: fee)
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("audit-envelope-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func mode(of path: String) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    return try #require(attributes[.posixPermissions] as? NSNumber).intValue & 0o777
}

private func blake2b256(_ data: Data) throws -> Data {
    try Hash().blake2b(data: data, digestSize: 32, encoder: RawEncoder.self)
}

// MARK: - serialization/toTextEnvelope:unescaped-string-interpolation

@Suite struct EnvelopeEscapingTests {
    @Test("A description holding a quote cannot add a type key to a key envelope")
    func injectedTypeInSigningKeyEnvelope() throws {
        let injected = #"x", "type": "PaymentVerificationKeyShelley_ed25519"#
        let json = """
        {"type": "PaymentSigningKeyShelley_ed25519", "description": \(String(reflecting: injected)), "cborHex": "\(skeyHex)"}
        """
        let key = try PaymentSigningKey.fromTextEnvelope(json, validateType: true)
        #expect(key.description == injected)

        let saved = try #require(try key.toTextEnvelope())
        let dict = try envelopeDict(saved)
        #expect(dict.count == 3)
        #expect(dict["type"] == "PaymentSigningKeyShelley_ed25519")
        #expect(dict["description"] == injected)
        #expect(dict["cborHex"] == skeyHex)
        #expect(throws: CardanoCoreError.self) {
            try PaymentVerificationKey.fromTextEnvelope(saved, validateType: true)
        }
        #expect(try PaymentSigningKey.fromTextEnvelope(saved, validateType: true) == key)
    }

    @Test("Control characters, quotes and backslashes in a TextEnvelopable round-trip as valid JSON")
    func controlCharactersInTextEnvelopable() throws {
        var body = testBody()
        body._description = "line\nbreak \"quoted\" back\\slash \u{01}\u{1F}\t\r\u{08}\u{0C} a/b"
        body._type = "TxBody ConwayEra\", \"type\": \"Other"
        let saved = try #require(try body.toTextEnvelope())
        let dict = try envelopeDict(saved)
        #expect(dict.count == 3)
        #expect(dict["description"] == body._description)
        #expect(dict["type"] == body._type)
        #expect(saved.contains("a/b"))
        #expect(saved.contains(#"\u0001"#) && saved.contains(#"\u001f"#))
    }

    @Test("Envelopes keep cardano-cli's layout: type, description, cborHex, four-space indent")
    func cardanoCliLayout() throws {
        let key = try PaymentSigningKey(payload: Data(repeating: 0xAB, count: 32))
        let saved = try #require(try key.toTextEnvelope())
        #expect(saved == """
        {
            "type": "PaymentSigningKeyShelley_ed25519",
            "description": "Payment Signing Key",
            "cborHex": "\(skeyHex)"
        }
        """)
    }

    @Test("A transaction envelope escapes its description too")
    func transactionDescriptionEscaped() throws {
        var tx = Transaction(transactionBody: testBody(), transactionWitnessSet: TransactionWitnessSet())
        tx._description = #"", "type": "Tx BabbageEra"#
        let dict = try envelopeDict(try #require(try tx.toTextEnvelope()))
        #expect(dict.count == 3)
        #expect(dict["type"] == "Unwitnessed Tx ConwayEra")
        #expect(dict["description"] == tx._description)
    }
}

// MARK: - SwiftCardanoCore/TextEnvelopable/stale-init-payload

@Suite struct EnvelopeCurrentFieldsTests {
    @Test("A body's envelope carries its current fee and the id it hashes to")
    func bodyEnvelopeUsesCurrentFields() throws {
        var body = testBody()
        body.fee = 999_999
        let reloaded = try TransactionBody.fromTextEnvelope(try #require(try body.toTextEnvelope()))
        #expect(reloaded.fee == 999_999)
        #expect(try reloaded.id == body.id)
    }

    @Test("save(to:) writes the transaction's own envelope, with current witnesses and fee")
    func transactionSaveMatchesToTextEnvelope() throws {
        let keyPair = try PaymentKeyPair.generate()
        var tx = Transaction(transactionBody: testBody(), transactionWitnessSet: TransactionWitnessSet())
        tx.transactionBody.fee = 300_000
        tx.transactionWitnessSet = TransactionWitnessSet(vkeyWitnesses: .list([VerificationKeyWitness(
            vkey: .verificationKey(keyPair.verificationKey),
            signature: try keyPair.signingKey.sign(data: tx.transactionBody.hash()))]))

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("tx.signed").path
        try tx.save(to: path)
        let written = try String(contentsOfFile: path, encoding: .utf8)
        #expect(written == (try tx.toTextEnvelope()))

        let reloaded = try Transaction.load(from: path)
        #expect(reloaded.type == "Tx ConwayEra")
        #expect(reloaded.transactionBody.fee == 300_000)
        #expect(reloaded.transactionWitnessSet.vkeyWitnesses?.count == 1)
        #expect(try reloaded.id == tx.id)
    }

    @Test("A key witness compares, hashes and saves its current signature")
    func witnessUsesCurrentFields() throws {
        let keyPair = try PaymentKeyPair.generate()
        let original = VerificationKeyWitness(
            vkey: .verificationKey(keyPair.verificationKey), signature: Data(repeating: 1, count: 64))
        var copy = original
        copy.signature = Data(repeating: 2, count: 64)
        #expect(copy != original)
        #expect(copy.hashValue != original.hashValue)

        let reloaded = try VerificationKeyWitness.fromTextEnvelope(try #require(try copy.toTextEnvelope()))
        #expect(reloaded.signature == Data(repeating: 2, count: 64))
        #expect(reloaded == copy)
    }

    @Test("An operational certificate's envelope carries its current fields and keeps the cold key")
    func operationalCertificateUsesCurrentFields() throws {
        let coldKey = try StakePoolKeyPair.generate().verificationKey
        var cert = try OperationalCertificate(
            hotVKey: KESVerificationKey(payload: Data(repeating: 0x01, count: KESConstants.publicKeySize)),
            sequenceNumber: 1, kesPeriod: 10, sigma: Data(repeating: 3, count: 64),
            coldVerificationKey: coldKey)
        cert.kesPeriod = 42
        cert.sequenceNumber = 7

        let reloaded = try OperationalCertificate.fromTextEnvelope(try #require(try cert.toTextEnvelope()))
        #expect(reloaded.kesPeriod == 42)
        #expect(reloaded.sequenceNumber == 7)
        #expect(reloaded.coldVerificationKey == coldKey)
        #expect(reloaded == cert)
    }
}

// MARK: - SwiftCardanoCore/Serialization/CBORSerializable.swift:fromCBORHex:secret-hex-in-error

@Suite struct HexErrorRedactionTests {
    let corrupted = "5820" + String(repeating: "ab", count: 31) + "zz"

    @Test("A corrupted signing key envelope's error does not echo the key hex")
    func signingKeyErrorOmitsHex() throws {
        let json = #"{"type":"PaymentSigningKeyShelley_ed25519","description":"Payment Signing Key","cborHex":"\#(corrupted)"}"#
        let error = #expect(throws: CardanoCoreError.self) {
            try PaymentSigningKey.fromTextEnvelope(json, validateType: true)
        }
        let text = String(describing: try #require(error))
        #expect(!text.contains(String(repeating: "ab", count: 31)))
        #expect(text.contains("\(corrupted.count)"))

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("bad.skey").path
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        let loadError = #expect(throws: CardanoCoreError.self) { try PaymentSigningKey.load(from: path) }
        #expect(!(loadError?.description.contains(String(repeating: "ab", count: 31)) ?? true))
    }

    @Test("A corrupted TextEnvelopable envelope's error does not echo its hex")
    func textEnvelopableErrorOmitsHex() throws {
        let json = #"{"type":"Tx ConwayEra","description":"","cborHex":"\#(corrupted)"}"#
        #expect(throws: CardanoCoreError.invalidArgument("Invalid hex string (\(corrupted.count) characters)")) {
            try Transaction.fromTextEnvelope(json)
        }
        #expect(throws: CardanoCoreError.invalidArgument("Invalid hex string (\(corrupted.count) characters)")) {
            try PaymentSigningKey.fromCBORHex(corrupted)
        }
    }
}
