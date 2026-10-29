import CBORCodable
import Foundation
import Testing

@testable import SwiftCardanoCore

/// Input that used to crash the process now throws, or decodes when it is
/// valid. A crash here ends the whole test run, so each case stands alone.
@Suite("Decoding never crashes: shared types")
struct DecodeCrashSystemicTests {
    let body = "00800180020" + "0"  // inputs [], outputs [], fee 0

    func bodyHex(_ fields: Int, _ extra: String) -> String {
        String(format: "a%x", fields) + body + extra
    }

    @Test("CBOR date tags stay tags and round trip", arguments: ["c100", "c06161", "c120"])
    func dateTags(hex: String) throws {
        let primitive = try CBORDecoder().decode(Primitive.self, from: hex.hexStringToData)
        guard case .cborTag = primitive else {
            Issue.record("expected a tag, got \(primitive)")
            return
        }
        #expect(try CBOREncoder().encode(primitive).toHex == hex)
    }

    @Test("Lengths and counts beyond the input are truncated, not overflowed", arguments: [
        "5bffffffffffffffff",
        "7bffffffffffffffff",
        "bb4000000000000000",
        "9bffffffffffffffff",
    ])
    func hugeLengths(hex: String) {
        #expect(throws: (any Error).self) { try TransactionBody.fromCBORHex(hex) }
        #expect(throws: (any Error).self) { try PlutusData.fromCBORHex(hex) }
        #expect(throws: (any Error).self) { try Transaction.fromCBORHex(hex) }
    }

    @Test("Deep nesting is read or rejected, never allowed to exhaust the stack")
    func deepNesting() async throws {
        for prefix in ["81", "c6", "9f"] {
            let data = Data(repeating: 0, count: 0)
                + String(repeating: prefix, count: 200_000).hexStringToData + Data([0x00])
            try await Task.detached {
                #expect(throws: (any Error).self) { try TransactionBody.fromCBOR(data: data) }
                #expect(throws: (any Error).self) { try Block.fromCBOR(data: data) }
                if prefix == "81" {
                    // Lists nested this deep are Plutus data; the ledger sets no depth limit.
                    #expect((try? PlutusData.fromCBOR(data: data).toCBORData()) == data)
                } else {
                    // Tag 6 is not Plutus data; the indefinite lists have no breaks.
                    #expect(throws: (any Error).self) { try PlutusData.fromCBOR(data: data) }
                }
            }.value
        }
    }

    @Test("A JSON tag must be a non-negative integer")
    func jsonTag() {
        #expect(throws: (any Error).self) { try Primitive.from(json: ["tag": -1, "value": 0]) }
        #expect(throws: (any Error).self) {
            try CBORTag.fromDict(.orderedDict([.string("tag"): .int(-1), .string("value"): .uint(0)]))
        }
        #expect(throws: (any Error).self) { try CBORTag.fromDict(.orderedDict([.string("tag"): .uint(1)])) }
    }

    @Test("Converting to AnyValue never traps")
    func anyValue() throws {
        let values: [Primitive] = [
            .cborTag(CBORTag(tag: UInt64.max, value: .uint(1))),
            .unitInterval(UnitInterval(numerator: UInt64.max, denominator: UInt64.max)),
            .plutusData(.constructor(Constr(tag: 0, fields: [.bigInt(.int(1))]))),
            .cborSimpleValue(.encoded("a201020103".hexStringToData)),
            .dict([.bytes(Data([0])): .uint(1), .byteArray([0]): .uint(2)]),
        ]
        for value in values { _ = value.toAnyValue() }
    }

    @Test("A body field that is out of range, unknown or malformed is rejected", arguments: [
        "0f1bffffffffffffffff",  // network id 2^64 - 1
        "0f02",  // network id 2
        "1bffffffffffffffff00",  // an unknown field number
        "2000",  // a negative field number
        "1700",  // field 23, which the ledger does not define
        "0320",  // a negative ttl
        "0e" + "d9010280",  // an empty required-signers set
    ])
    func malformedBodyFields(extra: String) {
        #expect(throws: (any Error).self) { try TransactionBody.fromCBORHex(bodyHex(4, extra)) }
    }

    @Test("A treasury donation up to 2^64 - 1 decodes and round trips")
    func largeDonation() throws {
        let hex = bodyHex(4, "161bffffffffffffffff")
        let body = try TransactionBody.fromCBORHex(hex)
        #expect(body.treasuryDonation?.value == UInt.max)
        var changed = body
        changed.fee = 1
        _ = try changed.toCBORData()
        _ = try changed.toDict()
    }

    @Test("A body read from JSON rejects a negative fee")
    func negativeJSONFee() {
        let json: Primitive = .orderedDict([
            .string("inputs"): .list([]), .string("outputs"): .list([]), .string("fee"): .int(-1),
        ])
        #expect(throws: (any Error).self) { try TransactionBody.fromDict(json) }
    }

    @Test("Sets decode their elements, and reject an empty non-empty set")
    func sets() {
        #expect(throws: (any Error).self) { try OrderedSet<TransactionInput>.fromCBORHex("8180") }
        #expect(throws: (any Error).self) { try NonEmptyOrderedSet<VerificationKeyHash>.fromCBORHex("8140") }
        #expect(throws: (any Error).self) { try NonEmptyOrderedSet<VerificationKeyHash>.fromCBORHex("d9010281a0") }
        #expect(throws: (any Error).self) { try NonEmptyOrderedSet<VerificationKeyHash>.fromCBORHex("d9010280") }
        #expect(throws: (any Error).self) { try ListOrNonEmptyOrderedSet<VerificationKeyHash>.fromCBORHex("d9010280") }
    }

    @Test("Intervals and fractions reject a zero denominator and read signs")
    func intervals() throws {
        #expect(throws: (any Error).self) { try Fraction.fromCBORHex("d81e826001") }
        #expect(throws: (any Error).self) { try Fraction.fromCBORHex("d81e820100") }
        let negative = try Fraction.fromCBORHex("d81e822001")
        #expect(negative.numerator == -1)
        #expect(try negative.toCBORHex() == "d81e822001")

        #expect(throws: (any Error).self) { try UnitInterval.fromCBORHex("d81e820100") }
        #expect(throws: (any Error).self) { try UnitInterval.fromCBORHex("d81e820201") }
        #expect(throws: (any Error).self) { try UnitInterval.fromCBORHex("d81e822001") }
        let json = #"{"numerator":1,"denominator":0}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) { try JSONDecoder().decode(UnitInterval.self, from: json) }
        #expect(try UnitInterval.fromCBORHex("d81e820102").denominator == 2)
    }

    @Test("Execution units reject a negative value")
    func exUnits() throws {
        #expect(throws: (any Error).self) { try ExUnits.fromCBORHex("822000") }
        // The ledger caps each field at Int64.max.
        #expect(throws: (any Error).self) { try ExUnits.fromCBORHex("821bffffffffffffffff01") }
        #expect(try ExUnits.fromCBORHex("821b7fffffffffffffff01").mem == UInt64(Int64.max))
    }
}
