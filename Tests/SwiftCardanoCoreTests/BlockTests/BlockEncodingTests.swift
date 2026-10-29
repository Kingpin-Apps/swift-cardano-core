import Foundation
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// A block's hash is the hash of its header as written, a transaction's id the
/// hash of its body as written, and the body commits to its auxiliary data and
/// — through `script_data_hash` — its datums and redeemers as written. So a
/// decoded block keeps the bytes of every one of them.
@Suite("A block keeps its encoding")
struct BlockEncodingTests {
    let body = "a300d9010281825820" + String(repeating: "11", count: 32) + "00"
        + "0180" + "021a000003e8"  // a fee written in five bytes
    // Redeemers whose datum is a 1 written in two bytes.
    let witnessSet = "a105818400001801820000"
    // Metadata as an indefinite-length map, its value written in two bytes.
    let auxiliaryData = "bf011801ff"

    func blake2b(_ hex: String) throws -> Data {
        try Hash().blake2b(data: hex.hexStringToData, digestSize: 32, encoder: RawEncoder.self)
    }

    func block() throws -> (hex: String, header: String) {
        let header = try makeHeader().toCBORHex()
        return ("85" + header + "81" + body + "81" + witnessSet + "a100" + auxiliaryData + "80", header)
    }

    @Test("A decoded block re-encodes to its bytes, and hashes what was written")
    func roundTrip() throws {
        let (hex, header) = try block()
        let decoded = try Block.fromCBORHex(hex)

        #expect(try decoded.toCBORHex() == hex)
        #expect(try decoded.header.hash() == (try blake2b(header)))
        #expect(try decoded.transactionBodies[0].id.payload == (try blake2b(body)))
        #expect(try decoded.auxiliaryDataSet[0]?.hash().payload == blake2b(auxiliaryData))
        #expect(try EraBlock.fromBlockCBOR(data: hex.hexStringToData, era: 6).block?.toCBORHex() == hex)
    }

    @Test("Changing one witness set re-encodes it alone")
    func changingAWitnessSet() throws {
        var decoded = try Block.fromCBORHex(try block().hex)
        decoded.transactionWitnessSets[0].vkeyWitnesses = .list([
            VerificationKeyWitness(
                vkey: .verificationKey(try VerificationKey(payload: Data(repeating: 0x01, count: 32))),
                signature: Data(repeating: 0x02, count: 64))
        ])

        let hex = try decoded.toCBORHex()
        #expect(hex.contains(body))
        #expect(hex.contains("05" + "818400001801820000"))
        #expect(hex.contains("a100" + auxiliaryData))
        #expect(try Block.fromCBORHex(hex).transactionBodies[0].id == decoded.transactionBodies[0].id)
    }
}
