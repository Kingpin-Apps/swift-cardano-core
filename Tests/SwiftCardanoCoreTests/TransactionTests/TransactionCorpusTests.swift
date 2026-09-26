import Foundation
import Testing

@testable import SwiftCardanoCore

/// Real ledger transactions of every era from Shelley to Conway.
///
/// The corpus lives in `data/tx-corpus/<era>/`: one `<hash>.hex` file per
/// transaction, named by its on-chain id, and a `MANIFEST.tsv` naming each
/// transaction's network, epoch and the features it exercises. The on-chain id
/// is an oracle independent of this package: it is what the ledger hashed.
@Suite("Transaction corpus")
struct TransactionCorpusTests {
    static let eras = ["shelley", "allegra", "mary", "alonzo", "babbage", "conway"]

    struct Entry: Sendable, CustomTestStringConvertible {
        var era: String
        var hash: String
        var features: [String]

        var testDescription: String { "\(era)/\(hash.prefix(12)) \(features.joined(separator: ","))" }

        func bytes() throws -> Data {
            let text = try TransactionCorpusTests.read("\(era)/\(hash).hex")
            let hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return try #require(Data(hexString: hex))
        }
    }

    static func read(_ path: String) throws -> String {
        let url = try #require(
            Bundle.module.resourceURL?.appendingPathComponent("data/tx-corpus/\(path)")
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    static let corpus: [Entry] = eras.flatMap { era -> [Entry] in
        guard let manifest = try? read("\(era)/MANIFEST.tsv") else { return [] }
        return manifest.split(separator: "\n").dropFirst().compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 5 else { return nil }
            return Entry(era: era, hash: fields[0], features: fields[4].split(separator: ",").map(String.init))
        }
    }

    @Test("The corpus is present")
    func corpusIsPresent() {
        #expect(Self.corpus.count == 74)
    }

    @Test("Decoding keeps the on-chain transaction id", arguments: corpus)
    func idMatchesChain(_ entry: Entry) throws {
        let tx = try Transaction.fromCBOR(data: try entry.bytes())
        #expect(tx.id?.payload.toHex == entry.hash)
        #expect(tx.transactionBody.hash().toHex == entry.hash)
    }

    @Test("Re-serializing an untouched transaction gives back its bytes", arguments: corpus)
    func roundTripsBytes(_ entry: Entry) throws {
        let bytes = try entry.bytes()
        let tx = try Transaction.fromCBOR(data: bytes)
        #expect(try tx.toCBORData() == bytes)
    }

    @Test("A text envelope keeps the transaction id", arguments: corpus.prefix(6))
    func textEnvelopeKeepsId(_ entry: Entry) throws {
        let hex = try entry.bytes().toHex
        let json = """
        {"type": "Tx ConwayEra", "description": "", "cborHex": "\(hex)"}
        """
        let tx = try Transaction.fromTextEnvelope(json)
        #expect(tx.id?.payload.toHex == entry.hash)
    }

    /// Transactions whose re-encoding from decoded values differs from what
    /// was written, so that keeping the written bytes is what makes them right.
    static let reencodingDiffers: [Entry] = corpus.filter { entry in
        guard let tx = try? Transaction.fromCBOR(data: entry.bytes()) else { return false }
        var rebuilt = tx.transactionBody
        rebuilt.fee = rebuilt.fee  // clears the kept bytes
        return (try? rebuilt.toCBORData()) != tx.transactionBody.originalCBOR
    }

    @Test("Part of the corpus does not survive a plain re-encoding")
    func corpusCoversReencoding() {
        #expect(!Self.reencodingDiffers.isEmpty)
    }

    @Test("Adding a witness keeps the written body and auxiliary data", arguments: reencodingDiffers)
    func addingWitnessKeepsBody(_ entry: Entry) throws {
        let bytes = try entry.bytes()
        var tx = try Transaction.fromCBOR(data: bytes)
        let auxiliaryBytes = tx.originalAuxiliaryDataCBOR

        let witness = VerificationKeyWitness(
            vkey: .verificationKey(try VerificationKey(payload: Data(repeating: 0x01, count: 32))),
            signature: Data(repeating: 0x02, count: 64)
        )
        var witnesses = tx.transactionWitnessSet
        witnesses.vkeyWitnesses = .list([witness])
        tx.transactionWitnessSet = witnesses

        #expect(tx.originalCBOR == nil)
        #expect(tx.id?.payload.toHex == entry.hash)

        let reencoded = try tx.toCBORData()
        #expect(reencoded != bytes)
        let decoded = try Transaction.fromCBOR(data: reencoded)
        #expect(decoded.id?.payload.toHex == entry.hash)
        #expect(decoded.originalAuxiliaryDataCBOR == auxiliaryBytes)
        #expect(decoded.transactionWitnessSet.vkeyWitnesses?.count == 1)
    }

    @Test("Changing the body changes its id", arguments: corpus.prefix(3))
    func changingBodyChangesId(_ entry: Entry) throws {
        var tx = try Transaction.fromCBOR(data: try entry.bytes())
        tx.transactionBody.fee = tx.transactionBody.fee + 1
        #expect(tx.transactionBody.originalCBOR == nil)
        #expect(tx.originalCBOR == nil)
        #expect(tx.id?.payload.toHex != entry.hash)
    }

    @Test("Shelley to Mary transactions keep their three-element shape")
    func preAlonzoShape() throws {
        let entry = try #require(Self.corpus.first { $0.era == "mary" && $0.features.contains("metadata") })
        var tx = try Transaction.fromCBOR(data: try entry.bytes())
        #expect(tx.isPreAlonzo)
        #expect(tx.auxiliaryData != nil)

        tx.valid = true  // clears the whole-transaction bytes only
        let reencoded = try tx.toCBORData()
        #expect(reencoded.first == 0x83)
        #expect(reencoded == (try entry.bytes()))
    }

    @Test("The text envelope keeps the era it was read with")
    func textEnvelopeEra() throws {
        let entry = try #require(Self.corpus.first { $0.era == "babbage" })
        let hex = try entry.bytes().toHex
        let json = """
        {"type": "Tx BabbageEra", "description": "", "cborHex": "\(hex)"}
        """
        let tx = try Transaction.fromTextEnvelope(json)
        let envelope = try #require(try tx.toTextEnvelope())
        #expect(envelope.contains("\"type\": \"Tx BabbageEra\""))

        var unsigned = tx
        unsigned.transactionWitnessSet = TransactionWitnessSet()
        let unsignedEnvelope = try #require(try unsigned.toTextEnvelope())
        #expect(unsignedEnvelope.contains("\"type\": \"Unwitnessed Tx BabbageEra\""))
    }

    @Test("A malformed payload throws instead of trapping")
    func malformedPayloadThrows() {
        #expect(throws: (any Error).self) {
            try Transaction(payload: Data([0x84, 0xA0]), type: nil, description: nil)
        }
        #expect(throws: (any Error).self) {
            try TransactionBody(payload: Data([0xA1, 0x00]), type: nil, description: nil)
        }
    }
}
