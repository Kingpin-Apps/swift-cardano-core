import Foundation
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// Real blocks from Shelley to Conway, from the test data of txpipe/pallas,
/// stored as the node writes them: `[era tag, block]`, tags 2 (Shelley) to 7
/// (Conway).
@Suite("Mainnet blocks keep their encoding")
struct MainnetBlockTests {
    static let eras: [UInt64: Era] = [2: .shelley, 3: .allegra, 4: .mary, 5: .alonzo, 6: .babbage, 7: .conway]

    static let files: [String] = {
        let url = Bundle.module.resourceURL!.appendingPathComponent("data/blocks")
        return ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }()

    static func load(_ directory: String, _ file: String) throws -> (era: Era, bytes: Data) {
        let url = Bundle.module.resourceURL!.appendingPathComponent("\(directory)/\(file)")
        let data = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines).hexStringToData
        let scanner = CBORItemScanner(data)
        let spans = try scanner.elements(ofArrayAt: 0)
        let tag = try #require(try scanner.unsignedInteger(at: spans[0].lowerBound))
        return (try #require(eras[tag]), data.subdata(in: spans[1]))
    }

    @Test("Every era is covered")
    func coverage() throws {
        let eras = Set(try Self.files.map { try Self.load("data/blocks", $0).era })
        #expect(eras == [.shelley, .allegra, .mary, .alonzo, .babbage, .conway])
    }

    @Test("A block re-encodes to its bytes, and its body hashes to what its header commits to",
        arguments: files)
    func roundTrip(file: String) throws {
        let (era, bytes) = try Self.load("data/blocks", file)
        let block = try Block.fromCBOR(data: bytes, era: era)

        #expect(try block.toCBORData() == bytes)
        #expect(try block.bodyHash() == block.header.headerBody.blockBodyHash)
        #expect(block.isPreAlonzo == (era < .alonzo))
        #expect(try EraBlock.fromBlockCBOR(data: bytes, era: UInt64(era.index)).block?.toCBORData() == bytes)
    }

    @Test("A block's hash is its header's, and each transaction id its body's", arguments: files)
    func hashes(file: String) throws {
        let (era, bytes) = try Self.load("data/blocks", file)
        let block = try Block.fromCBOR(data: bytes, era: era)
        let scanner = CBORItemScanner(bytes)
        let spans = try scanner.elements(ofArrayAt: 0)

        #expect(block.hash() == (try Hash().blake2b(
            data: bytes.subdata(in: spans[0]), digestSize: 32, encoder: RawEncoder.self)))
        for (body, span) in zip(block.transactionBodies, try scanner.elements(ofArrayAt: spans[1].lowerBound)) {
            #expect(body.id.payload == (try Hash().blake2b(
                data: bytes.subdata(in: span), digestSize: 32, encoder: RawEncoder.self)))
        }
    }

    @Test("Changing one witness set re-encodes it alone; the body hash then follows the change")
    func changingAWitnessSet() throws {
        let (era, bytes) = try Self.load("data/blocks", "babbage4.block")
        var block = try Block.fromCBOR(data: bytes, era: era)
        let bodies = block.transactionBodies.map { try? $0.toCBORData() }
        block.transactionWitnessSets[0].vkeyWitnesses = nil

        let changed = try Block.fromCBOR(data: block.toCBORData(), era: era)
        #expect(changed.transactionBodies.map { try? $0.toCBORData() } == bodies)
        #expect(try changed.bodyHash() != block.header.headerBody.blockBodyHash)
        #expect(try changed.bodyHash() == block.bodyHash())
    }

    @Test("A pre-release protocol parameter out of today's range fails to decode, not crash")
    func outOfRangeParameter() throws {
        // A SanchoNet block whose proposal sets nOpt to 2^64 - 1; the ledger
        // reads nOpt as a Word16 and rejects it.
        let (era, bytes) = try Self.load("data/blocks-prerelease", "conway4.block")
        #expect(throws: CardanoCoreError.self) { try Block.fromCBOR(data: bytes, era: era) }
    }

    @Test("A hash of the wrong length fails to decode, as today's node rejects it")
    func wrongHashLength() throws {
        // pallas's "peculiar block with hash-size issue": a stake delegation
        // whose pool key hash is 56 bytes. Older cardano-base packed hashes
        // without checking their length; today's checks it exactly, and so
        // does this.
        let (era, bytes) = try Self.load("data/blocks-prerelease", "conway8.block")
        #expect(throws: CardanoCoreError.self) { try Block.fromCBOR(data: bytes, era: era) }
    }
}
