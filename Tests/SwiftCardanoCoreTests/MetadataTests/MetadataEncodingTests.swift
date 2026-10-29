import BigInt
import Foundation
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// The body commits to the hash of the auxiliary data as written, so decoded
/// auxiliary data has to re-encode to the bytes it was read from. Metadata
/// built in code has to encode the same way every time, and within the
/// ledger's limits.
@Suite("Metadata keeps its encoding")
struct MetadataEncodingTests {
    func blake2b(_ hex: String) throws -> Data {
        try Hash().blake2b(
            data: hex.hexStringToData, digestSize: AUXILIARY_DATA_HASH_SIZE, encoder: RawEncoder.self)
    }

    @Test("Metadata decodes from CBOR, keeping its label order")
    func fromCBOR() throws {
        // {2: "a", 1: -1}
        let metadata = try Metadata.fromCBORHex("a20261610120")
        #expect(Array(metadata.data.keys) == [2, 1])
        #expect(metadata[1] == .int(-1))
        #expect(try metadata.toCBORHex() == "a20261610120")
    }

    @Test("A negative integer encodes")
    func negativeInteger() throws {
        #expect(try Metadata([1: .int(-1)]).toCBORHex() == "a10120")
        #expect(try Metadata([1: .int(Int.min)]).toCBORHex() == "a1013b7fffffffffffffff")
    }

    @Test("Metadata built from a dictionary is written in label order")
    func labelOrder() throws {
        let metadata = try Metadata([3: .int(0), 1: .int(0), 2: .int(0)])
        #expect(Array(metadata.data.keys) == [1, 2, 3])
        #expect(try metadata.toCBORHex() == "a3010002000300")
    }

    @Test("Integers across the whole range CBOR carries", arguments: [
        ("a1011bffffffffffffffff", BigInt(1) << 64 - 1),
        ("a1013bffffffffffffffff", -(BigInt(1) << 64)),
        ("a1013b8000000000000000", -(BigInt(1) << 63) - 1),
        ("a101c249010000000000000000", BigInt(1) << 64),
        ("a101c349010000000000000000", -(BigInt(1) << 64) - 1),
    ])
    func integerRange(hex: String, value: BigInt) throws {
        let metadata = try Metadata.fromCBORHex(hex)
        #expect(metadata[1]?.integerValue == value)
        #expect(try metadata.toCBORHex() == hex)
        #expect(try Metadata([1: .integer(value)]).toCBORHex() == hex)
    }

    @Test("An integer compares and hashes alike whichever case holds it")
    func integerEquality() {
        #expect(TransactionMetadatum.int(5) == .bigInt(5))
        #expect(TransactionMetadatum.int(5).hashValue == TransactionMetadatum.bigInt(5).hashValue)
        #expect(TransactionMetadatum.integer(5) == .int(5))
    }

    @Test("Strings over 64 bytes are rejected when built, but read when decoded")
    func sizeLimit() throws {
        let long = String(repeating: "a", count: 65)
        #expect(throws: CardanoCoreError.self) { try Metadata([1: .text(long)]) }
        #expect(throws: CardanoCoreError.self) {
            try Metadata([1: .list([.bytes(Data(count: 65))])])
        }
        #expect(throws: CardanoCoreError.self) {
            try Metadata([1: .map([.text(long): .int(0)])])
        }

        // Early Shelley metadata, before the ledger enforced the limit.
        let hex = "a1017841" + Data(long.utf8).toHex
        #expect(try Metadata.fromCBORHex(hex)[1] == .text(long))
    }

    @Test("Auxiliary data re-encodes to its bytes, and hashes them", arguments: [
        "a1011801",  // a one written in two bytes
        "bf0101ff",  // an indefinite-length map
        "a1017f6161ff",  // an indefinite-length text string
        "a1015f4101ff",  // a chunked byte string
        "a202010101",  // labels out of order
        "82a1010180",  // Shelley-Mary: [metadata, native scripts]
        "d90103a100a10101",  // Alonzo: #6.259({0: metadata})
    ])
    func auxiliaryDataRoundTrip(hex: String) throws {
        let auxiliaryData = try AuxiliaryData.fromCBORHex(hex)
        #expect(try auxiliaryData.toCBORHex() == hex)
        #expect(try auxiliaryData.hash().payload == blake2b(hex))
    }

    @Test("Indefinite-length forms read as their values")
    func indefiniteForms() throws {
        guard case .metadata(let metadata) = try AuxiliaryData.fromCBORHex("bf017f6161ff025f4101ffff").data
        else {
            Issue.record("not plain metadata")
            return
        }
        #expect(metadata[1] == .text("a"))
        #expect(metadata[2] == .bytes(Data([0x01])))
    }

    @Test("Changed auxiliary data is encoded afresh")
    func changeClearsBytes() throws {
        var auxiliaryData = try AuxiliaryData.fromCBORHex("a1011801")
        auxiliaryData.data = .metadata(try Metadata([1: .int(2)]))
        #expect(try auxiliaryData.toCBORHex() == "a10102")
    }

    @Test("Metadata compares by content, not label order")
    func equality() throws {
        let lhs = try Metadata.fromCBORHex("a202010101")
        let rhs = try Metadata([1: .int(1), 2: .int(1)])
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test("Metadata round-trips through JSON with every value kept as it is")
    func jsonRoundTrip() throws {
        let metadata = try Metadata([
            1: .bytes(Data([0x01, 0x02])),
            2: .text("0102"),
            3: .map([.int(1): .text("int key"), .text("1"): .text("text key"), .int(1): .text("again")]),
            4: .list([.bigInt(BigInt(1) << 70), .int(-5)]),
        ])
        let json = try metadata.toDict()
        #expect(try Metadata.fromDict(json) == metadata)
        #expect(try Metadata.fromDict(json).toCBORData() == metadata.toCBORData())
    }

    @Test("Plain JSON values are read too")
    func plainJSON() throws {
        let metadatum = try TransactionMetadatum.fromDict(
            .orderedDict([.string("name"): .string("x"), .string("n"): .int(3)]))
        #expect(metadatum == .map([.text("name"): .text("x"), .text("n"): .int(3)]))
    }
}
