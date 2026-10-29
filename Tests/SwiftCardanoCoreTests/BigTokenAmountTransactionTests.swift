import BigInt
import Foundation
import Testing
@testable import SwiftCardanoCore

/// A whole transaction whose output tokens sit above `Int64.max` and whose mint
/// reaches both ends of the signed 64-bit range. Mainnet holds no such amounts
/// to test against, so the bytes are written by hand and the id is Blake2b-256
/// of the body, worked out apart from this package.
///
/// The ledger reads output amounts as `Word64` (`decodeMaryValue`) and mint
/// amounts as `Int64` (`decodeIntegerBounded64`).
@Suite struct BigTokenAmountTransactionTests {
    let keyHash = String(repeating: "11", count: 28)
    let policy = String(repeating: "22", count: 28)

    func hex(_ string: String) throws -> Data {
        try #require(Data(hexString: string.replacingOccurrences(of: " ", with: "")))
    }

    func body(output: String = "1b8000000000000000", mint: String = "3b7fffffffffffffff") -> String {
        "a4"
            + " 00 81 82 5820 \(String(repeating: "33", count: 32)) 00"
            + " 01 81 82 581d 61\(keyHash) 82 1bffffffffffffffff"
            + " a1 581c\(policy) a2 4161 1bffffffffffffffff 4162 \(output)"
            + " 02 1903e8"
            + " 09 a1 581c\(policy) a2 4161 1b7fffffffffffffff 4162 \(mint)"
    }

    func transaction(_ body: String) throws -> Data {
        try hex("84 \(body) a0 f5 f6")
    }

    func amounts(_ tx: Transaction) throws -> (outputA: BigInt?, outputB: BigInt?, mintA: BigInt?, mintB: BigInt?) {
        let policyId = ScriptHash(payload: try hex(policy))
        let a = try AssetName(payload: Data("a".utf8))
        let b = try AssetName(payload: Data("b".utf8))
        let output = tx.transactionBody.outputs.first?.amount.multiAsset[policyId]
        let mint = tx.transactionBody.mint?[policyId]
        return (output?[a], output?[b], mint?[a], mint?[b])
    }

    @Test("The transaction decodes, keeps its bytes and its id")
    func decodesAndKeepsBytes() throws {
        let bytes = try transaction(body())
        let tx = try Transaction.fromCBOR(data: bytes, era: .conway)

        let read = try amounts(tx)
        #expect(read.outputA == BigInt(UInt64.max))
        #expect(read.outputB == BigInt(Int64.max) + 1)
        #expect(read.mintA == BigInt(Int64.max))
        #expect(read.mintB == BigInt(Int64.min))
        #expect(tx.transactionBody.outputs.first?.amount.coin == BigInt(UInt64.max))

        #expect(try tx.toCBORData() == bytes)
        #expect(try tx.transactionBody.id.payload.toHex
                == "686e7f8c8979a911eaab994febf142bc22d42e2c40cd3e96e3b013c438eeb64a")
    }

    @Test("Encoded afresh, the amounts are written as the ledger writes them")
    func reEncodes() throws {
        var tx = try Transaction.fromCBOR(data: try transaction(body()), era: .conway)
        tx.transactionBody.fee = tx.transactionBody.fee // drops the kept bytes
        let fresh = try tx.toCBORData()
        let reread = try Transaction.fromCBOR(data: fresh, era: .conway)

        let before = try amounts(tx)
        let after = try amounts(reread)
        #expect(after.outputA == before.outputA)
        #expect(after.outputB == before.outputB)
        #expect(after.mintA == before.mintA)
        #expect(after.mintB == before.mintB)
        let written = fresh.toHex
        #expect(written.contains("1bffffffffffffffff"))
        #expect(written.contains("1b8000000000000000"))
        #expect(written.contains("3b7fffffffffffffff"))
    }

    @Test("Amounts past the ledger's ranges fail the whole transaction")
    func rejectsOutOfRange() throws {
        // An output token of 2^64.
        #expect(throws: (any Error).self) {
            _ = try Transaction.fromCBOR(data: try transaction(body(output: "c249010000000000000000")), era: .conway)
        }
        // A mint of 2^63 and of -2^63 - 1.
        for mint in ["1b8000000000000000", "3b8000000000000000"] {
            #expect(throws: (any Error).self) {
                _ = try Transaction.fromCBOR(data: try transaction(body(mint: mint)), era: .conway)
            }
        }
    }
}
