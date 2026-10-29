import BigInt
import Foundation
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// Plutus data has to re-encode to the bytes it was read from, or its hash —
/// and any signature over a body that commits to it — moves. And Plutus data
/// built in code has to be written the way the ledger accepts it: a byte
/// string over 64 bytes in chunks of at most 64.
///
/// The cases follow pycardano issue 507 and pull requests 508 and 509.
@Suite("Plutus data keeps its encoding")
struct PlutusDataEncodingTests {
    let long = String(repeating: "ab", count: 182)

    /// `Constr 0 [bytes]`, the bytes chunked at `widths`.
    func chunkedConstr(_ widths: [Int]) -> String {
        let payload = Data((0..<widths.reduce(0, +)).map { UInt8($0 & 0xFF) })
        var start = 0
        var body = ""
        for width in widths {
            body += String(format: "58%02x", width) + payload[start..<start + width].toHex
            start += width
        }
        return "d8799f5f" + body + "ffff"
    }

    func isChunked(_ hex: String) -> Bool { hex.contains("5f5840") }

    func expectRoundTrip(_ hex: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let typed = try PlutusData.fromCBORHex(hex)
        #expect(try typed.toCBORHex() == hex, "PlutusData", sourceLocation: sourceLocation)
        let raw = try RawPlutusData.fromCBORHex(hex)
        #expect(try raw.toCBORHex() == hex, "RawPlutusData", sourceLocation: sourceLocation)
        #expect(try raw.copy().toCBORHex() == hex, "RawPlutusData.copy", sourceLocation: sourceLocation)
    }

    // MARK: - pycardano 507: chunking survives a copy and a round trip

    @Test("Long bytes from a dictionary are chunked, and stay chunked through a copy")
    func rawFromDict() throws {
        let datum = try RawPlutusData.fromDict(["constructor": 0, "fields": [["bytes": long]]])
        let encoded = try datum.toCBORHex()

        #expect(isChunked(encoded))
        #expect(try datum.copy().toCBORHex() == encoded)
        #expect(try RawPlutusData.fromCBORHex(encoded).toCBORHex() == encoded)
    }

    @Test("Long bytes stay chunked in a map key, a map value and a list")
    func rawNested() throws {
        let map = try RawPlutusData.fromDict([
            "map": [["k": ["bytes": String(repeating: "cd", count: 100)],
                     "v": ["bytes": String(repeating: "ef", count: 100)]]]
        ])
        let list = try RawPlutusData.fromDict(["list": [["bytes": String(repeating: "ab", count: 65)]]])

        for datum in [map, list] {
            let encoded = try datum.toCBORHex()
            #expect(isChunked(encoded))
            #expect(!encoded.contains("5864"), "a 100-byte string written definite")
            #expect(try RawPlutusData.fromCBORHex(encoded).toCBORHex() == encoded)
            #expect(try datum.copy().toCBORHex() == encoded)
        }
    }

    @Test("Long bytes in untyped data built in code are chunked")
    func rawBuiltByHand() throws {
        let bytes = Data(repeating: 0xAB, count: 182)
        let constr = RawPlutusData(data: .cborTag(CBORTag(tag: 121, value: .list([.bytes(bytes)]))))
        let topLevel = RawPlutusData(data: .bytes(bytes))
        let typed = PlutusData.bytes(try Bytes(from: bytes))

        #expect(try topLevel.toCBORHex() == typed.toCBORHex())
        for datum in [constr, topLevel] {
            let encoded = try datum.toCBORHex()
            #expect(isChunked(encoded))
            #expect(try RawPlutusData.fromCBORHex(encoded).toCBORHex() == encoded)
            #expect(try datum.copy().toCBORHex() == encoded)
        }
    }

    @Test("A datum hash over untyped long bytes matches the typed one")
    func datumHashOfUntypedBytes() throws {
        let bytes = Data(repeating: 0xAB, count: 182)
        let typed = try datumHash(datum: .plutusData(.bytes(try Bytes(from: bytes))))

        #expect(try datumHash(datum: .bytes(bytes)) == typed)
        #expect(try datumHash(datum: .rawPlutusData(RawPlutusData(data: .bytes(bytes)))) == typed)
    }

    // MARK: - pycardano 508: what was read is written back as it was

    @Test("A chunked datum re-encodes to the same bytes, and so the same hash")
    func chunkedDatumKeepsItsHash() throws {
        let hex = "d8799f5f5840" + Data(0..<64).toHex + "48" + String(repeating: "00", count: 8) + "ffff"
        try expectRoundTrip(hex)

        let wireHash = try Hash().blake2b(
            data: hex.hexStringToData, digestSize: DATUM_HASH_SIZE, encoder: RawEncoder.self)
        #expect(try PlutusData.fromCBORHex(hex).hash().payload == wireHash)
    }

    @Test("Bytes chunked at 60/60/62 keep those widths")
    func keepsChunkWidths() throws {
        try expectRoundTrip(chunkedConstr([60, 60, 62]))
    }

    @Test("Short bytes read in chunks keep their chunks")
    func shortChunkedBytes() throws {
        try expectRoundTrip("d8799f5f4101ffff")
        try expectRoundTrip("5f41014102ff")
        try expectRoundTrip("5fff")
    }

    @Test("Short bytes are not chunked")
    func shortBytesStayDefinite() throws {
        let datum = try RawPlutusData.fromDict([
            "constructor": 1, "fields": [["bytes": String(repeating: "ab", count: 32)], ["int": 42]],
        ])
        let encoded = try datum.toCBORHex()

        #expect(!encoded.contains("5f"))
        #expect(try RawPlutusData.fromCBORHex(encoded).toCBORHex() == encoded)
        #expect(try datum.copy().toCBORHex() == encoded)
    }

    @Test("Indefinite-length maps keep their header", arguments: [
        "bf0102ff",
        "bfff",
        "bf01bf0203ffff",
        "d8799fbf0102ffff",
        "9fbf0102ffff",
    ])
    func indefiniteMaps(hex: String) throws {
        try expectRoundTrip(hex)
    }

    @Test("A definite map keeps its order")
    func definiteMapOrder() throws {
        try expectRoundTrip("a202030104")
    }

    @Test("Chunked bytes as a map key keep their chunks")
    func chunkedMapKey() throws {
        try expectRoundTrip("a15f4101ff02")
        try expectRoundTrip("a15f5840" + Data(0..<64).toHex + "4101ff02")
    }

    @Test("A map compares and hashes the same whichever header it was written with")
    func mapEquality() throws {
        let definite = try PlutusData.fromCBORHex("a10102")
        let indefinite = try PlutusData.fromCBORHex("bf0102ff")

        #expect(definite == indefinite)
        #expect(definite.hashValue == indefinite.hashValue)
        #expect([definite: "v"][indefinite] == "v")
        #expect(definite.mapEntries == indefinite.mapEntries)
        #expect(definite.mapEntries?.count == 1)
    }

    @Test("Untyped data read from a map converts to typed data")
    func rawMapToPlutusData() throws {
        let raw = try RawPlutusData.fromCBORHex("bf0102ff")
        #expect(try raw.toPlutusData() == PlutusData.fromCBORHex("a10102"))
    }

    // MARK: - Integers

    @Test("Integers across the whole range keep their encoding", arguments: [
        "1bffffffffffffffff",  // 2^64 - 1
        "3b7fffffffffffffff",  // -2^63
        "3b8000000000000000",  // -2^63 - 1
        "3bffffffffffffffff",  // -2^64
        "c249010000000000000000",  // 2^64
        "c349010000000000000000",  // -2^64 - 1
    ])
    func integerRange(hex: String) throws {
        try expectRoundTrip(hex)
    }

    @Test("Integers are read with their value", arguments: [
        ("3bffffffffffffffff", -(BigInt(1) << 64)),
        ("3b8000000000000000", -(BigInt(1) << 63) - 1),
        ("1bffffffffffffffff", (BigInt(1) << 64) - 1),
    ])
    func integerValues(hex: String, value: BigInt) throws {
        guard case .bigInt(let integer) = try PlutusData.fromCBORHex(hex) else {
            Issue.record("not an integer")
            return
        }
        #expect(integer.value == value)
        #expect(try PlutusData.bigInt(BigInteger(from: .bigInt(value))).toCBORHex() == hex)
    }

    @Test("A bignum over 64 bytes is written in chunks of 64")
    func longBignum() throws {
        // 2^512: a one and 64 zero bytes.
        let hex = "c25f5840" + "01" + String(repeating: "00", count: 63) + "4100" + "ff"
        let value = PlutusData.bigInt(try BigInteger(from: .bigInt(BigInt(1) << 512)))
        #expect(try value.toCBORHex() == hex)
        #expect(try PlutusData.fromCBORHex(hex) == value)
        try expectRoundTrip(hex)
    }

    // MARK: - Malformed input

    @Test("A map that repeats a key is rejected rather than re-encoded wrongly")
    func duplicateKeys() {
        // {1: [2], 1: [_ 2]}
        #expect(throws: (any Error).self) { try PlutusData.fromCBORHex("a2018102019f02ff") }
        #expect(throws: (any Error).self) { try RawPlutusData.fromCBORHex("a2018102019f02ff") }
    }

    @Test("Bytes after the datum are rejected")
    func trailingBytes() {
        #expect(throws: (any Error).self) { try PlutusData.fromCBORHex("0102") }
        #expect(throws: (any Error).self) { try RawPlutusData.fromCBORHex("0102") }
    }
}
