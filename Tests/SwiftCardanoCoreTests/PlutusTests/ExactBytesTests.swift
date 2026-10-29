import Foundation
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// A datum decoded and left unchanged keeps the exact bytes it was read
/// from — header widths included — so its hash and its size are those of what
/// was written.
@Suite("Datums keep their exact bytes")
struct ExactBytesTests {
    // Constr 0 [1], the 1 written in two bytes and the list's length in two.
    let datum = "d879980118" + "01"

    func blake2b(_ hex: String) throws -> Data {
        try Hash().blake2b(data: hex.hexStringToData, digestSize: DATUM_HASH_SIZE, encoder: RawEncoder.self)
    }

    @Test("RawPlutusData re-encodes and hashes as written")
    func rawPlutusData() throws {
        let raw = try RawPlutusData.fromCBORHex(datum)
        #expect(try raw.toCBORHex() == datum)
        #expect(try datumHash(datum: .rawPlutusData(raw)).payload == blake2b(datum))
        #expect(try raw.toPlutusData() == PlutusData.fromCBORHex("d8798101"))
    }

    @Test("An inline datum keeps its bytes and is hashed over them")
    func inlineDatum() throws {
        let option = "8201d81846" + datum
        let decoded = try DatumOption.fromCBORHex(option)
        #expect(try decoded.toCBORHex() == option)
        #expect(decoded.datumCBOR?.toHex == datum)
        #expect(try decoded.inlineDatumHash()?.payload == blake2b(datum))
    }

    @Test("An unchanged output keeps its bytes when its body is changed")
    func outputInChangedBody() throws {
        let output = "a300581d60" + String(repeating: "aa", count: 28) + "011a004c4b40" + "028201d81846" + datum
        let body = "a300d9010281825820" + String(repeating: "11", count: 32) + "00" + "0181" + output
            + "021a00030d40"
        var decoded = try TransactionBody.fromCBORHex(body)
        #expect(try decoded.outputs[0].toCBORHex() == output)

        decoded.fee = 300_000
        let changed = try decoded.toCBORHex()
        #expect(changed != body)
        #expect(changed.contains(output))
    }

    @Test("Plutus data rejects what the ledger does not read as Plutus data", arguments: [
        "6161",  // a text string
        "f93c00",  // a float
        "f5",  // a simple value
        "c11a00000000",  // tag 1
        "d8180101",  // tag 24
        "d9057900",  // tag 1401, past the constructor range
    ])
    func rejects(hex: String) {
        #expect(throws: (any Error).self) { try PlutusData.fromCBORHex(hex) }
        #expect(throws: (any Error).self) { try RawPlutusData.fromCBORHex(hex) }
    }
}
