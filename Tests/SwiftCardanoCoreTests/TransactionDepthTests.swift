import Foundation
import SwiftNaCl
import Testing
@testable import SwiftCardanoCore

/// The ledger reads Plutus data, metadata and native scripts with no depth
/// limit, so a transaction can nest them as deep as its size allows — and a
/// preprod block holds a native script nested 5,383 deep. Every such
/// transaction decodes, keeps its bytes and id, re-encodes, and is freed, on
/// a cooperative thread's 512 KB stack.
@Suite struct TransactionDepthTests {
    static func blake2b(_ data: Data, _ size: Int) throws -> Data {
        try Hash().blake2b(data: data, digestSize: size, encoder: RawEncoder.self)
    }

    static func hex(_ string: String) -> Data {
        Data(hexString: string.replacingOccurrences(of: " ", with: ""))!
    }

    static func byteString(_ payload: Data) -> String {
        let n = payload.count
        let head = n < 24 ? String(format: "%02x", 0x40 + n)
            : n < 256 ? "58" + String(format: "%02x", n) : "59" + String(format: "%04x", n)
        return head + payload.toHex
    }

    static func constrs(_ n: Int) -> String { String(repeating: "d87981", count: n) + "00" }
    static func lists(_ n: Int) -> String { String(repeating: "81", count: n) + "00" }
    static func maps(_ n: Int) -> String { String(repeating: "a100", count: n) + "00" }
    static func scripts(_ n: Int) -> String {
        String(repeating: "820181", count: n) + "8200581c" + String(repeating: "44", count: 28)
    }

    static let input = "00 81 82 5820" + String(repeating: "33", count: 32) + "00"
    static let address = "581d61" + String(repeating: "11", count: 28)
    static let body = "a3 \(input) 01 80 02 00"

    static func transaction(body: String = body, witnesses: String = "a0", auxiliary: String = "f6") -> Data {
        hex("84 \(body) \(witnesses) f5 \(auxiliary)")
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let bytes: Data
        var testDescription: String { name }
    }

    /// Each as deep as fits in a 16 KB transaction, or near it.
    static let cases: [Case] = [
        Case(name: "witness datum, constructors", bytes: transaction(witnesses: "a1 04 81 \(constrs(5_000))")),
        Case(name: "witness datum, lists", bytes: transaction(witnesses: "a1 04 81 \(lists(16_000))")),
        Case(name: "redeemer data", bytes: transaction(witnesses: "a1 05 a1 82 00 00 82 \(constrs(5_000)) 82 00 00")),
        Case(name: "inline datum", bytes: transaction(
            body: "a3 \(input) 01 81 a3 00 \(address) 01 00 02 82 01 d818 \(byteString(hex(constrs(5_000)))) 02 00")),
        Case(name: "metadata, lists", bytes: transaction(auxiliary: "a1 01 \(lists(16_000))")),
        Case(name: "metadata, maps", bytes: transaction(auxiliary: "a1 01 \(maps(8_000))")),
        Case(name: "native script", bytes: transaction(witnesses: "a1 01 81 \(scripts(5_383))")),
    ]

    @Test(arguments: cases)
    func decodesKeepsAndFrees(_ test: Case) async throws {
        let bytes = test.bytes
        let bodyEnd = try CBORItemScanner(bytes).elements(ofArrayAt: 0)[0]
        let expectedId = try Self.blake2b(bytes.subdata(in: bodyEnd), 32)
        try await Task.detached {
            let tx = try Transaction.fromCBOR(data: bytes)
            #expect(try tx.toCBORData() == bytes)
            #expect(try tx.transactionBody.id.payload == expectedId)
            #expect(try Transaction.fromCBOR(data: bytes) == tx)
            _ = tx.hashValue

            // Encoded afresh, every part is written again and reads back equal.
            var changed = tx
            changed.transactionWitnessSet.vkeyWitnesses = nil
            changed.auxiliaryData?.originalCBOR = nil
            changed.transactionBody.fee = 0
            let fresh = try changed.toCBORData()
            #expect(try Transaction.fromCBOR(data: fresh) == tx)
        }.value
    }

    @Test("The deep script keeps its hash, taken over its encoding")
    func scriptHash() throws {
        let script = Self.hex(Self.scripts(5_383))
        let tx = try Transaction.fromCBOR(data: Self.transaction(witnesses: "a1 01 81 \(script.toHex)"))
        let decoded = try #require(tx.transactionWitnessSet.nativeScripts?.asList.first)
        #expect(try decoded.scriptHash().payload == Self.blake2b(Data([0x00]) + script, 28))
    }

    @Test("A block whose transaction holds a datum as deep as a transaction allows")
    func deepDatumInABlock() async throws {
        let (era, original) = try MainnetBlockTests.load("data/blocks", "conway1.block")
        let scanner = CBORItemScanner(original)
        let parts = try scanner.elements(ofArrayAt: 0)
        let witnessSets = try scanner.elements(ofArrayAt: parts[2].lowerBound)
        // The first transaction's witness set, replaced by one holding a deep datum.
        var replaced = CBORItemScanner.definiteHeader(major: 4, count: witnessSets.count)
        replaced += Self.hex("a1 04 81 \(Self.constrs(5_000))")
        for span in witnessSets.dropFirst() { replaced += original.subdata(in: span) }
        var bytes = CBORItemScanner.definiteHeader(major: 4, count: parts.count)
        for (index, span) in parts.enumerated() {
            bytes += index == 2 ? replaced : original.subdata(in: span)
        }
        let block = bytes
        try await Task.detached {
            let decoded = try Block.fromCBOR(data: block, era: era)
            #expect(try decoded.toCBORData() == block)
            _ = try decoded.bodyHash()
        }.value
    }
}
