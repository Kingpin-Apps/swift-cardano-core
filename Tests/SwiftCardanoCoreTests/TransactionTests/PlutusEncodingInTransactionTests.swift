import Foundation
import OrderedCollections
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

/// Plutus data in a transaction has to keep its bytes: the body commits to the
/// redeemers and witness datums through `script_data_hash`, and every witness
/// signs the body. Adding a witness re-encodes the witness set, so the
/// redeemers in it must come back exactly as they were read.
///
/// Follows pycardano issues 402 and 507.
@Suite("Plutus data in a transaction keeps its encoding")
struct PlutusEncodingInTransactionTests {
    /// `Constr 0 [bytes]`, 182 bytes chunked at 60/60/62.
    static let datum: String = {
        let payload = Data((0..<182).map { UInt8($0) })
        return "d8799f5f" + "583c" + payload[0..<60].toHex + "583c" + payload[60..<120].toHex
            + "583e" + payload[120..<182].toHex + "ffff"
    }()

    /// Redeemers as an indefinite-length map, `{_ [spend, 0]: [datum, [0, 0]]}`,
    /// and the datum again as a witness datum.
    static let witnessSet = "a2" + "04" + "81" + datum + "05" + "bf" + "820000" + "82" + datum + "820000" + "ff"

    func body() throws -> TransactionBody {
        let input = TransactionInput(
            transactionId: try TransactionId(payload: Data(repeating: 0x11, count: 32)), index: 0)
        let address = try Address(
            from: .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"))
        let datum = PlutusData.constructor(
            Constr(tag: 0, fields: [.bytes(try Bytes(from: Data(repeating: 0xAB, count: 182)))]))
        let output = TransactionOutput(
            address: address, amount: Value(coin: 5_000_000),
            datumOption: DatumOption(datum: datum), postAlonzo: true)
        return TransactionBody(inputs: .orderedSet(try OrderedSet([input])), outputs: [output], fee: 200_000)
    }

    @Test("The witness set re-encodes to its bytes")
    func witnessSetRoundTrip() throws {
        let witnesses = try TransactionWitnessSet.fromCBORHex(Self.witnessSet)
        #expect(try witnesses.toCBORHex() == Self.witnessSet)
    }

    @Test("Adding a witness keeps the redeemers and witness datums as written")
    func addingWitnessKeepsRedeemers() throws {
        let unsigned = "84" + (try body().toCBORHex()) + Self.witnessSet + "f5f6"
        var tx = try Transaction.fromCBORHex(unsigned)

        var witnesses = tx.transactionWitnessSet
        witnesses.vkeyWitnesses = .list([
            VerificationKeyWitness(
                vkey: .verificationKey(try VerificationKey(payload: Data(repeating: 0x01, count: 32))),
                signature: Data(repeating: 0x02, count: 64))
        ])
        tx.transactionWitnessSet = witnesses

        let signed = try tx.toCBORHex()
        #expect(signed.contains("04" + "81" + Self.datum))
        #expect(signed.contains("05" + "bf" + "820000" + "82" + Self.datum + "820000" + "ff"))
        #expect(try Transaction.fromCBORHex(signed).transactionBody.hash() == tx.transactionBody.hash())
    }

    func witness() throws -> ListOrNonEmptyOrderedSet<VerificationKeyWitness> {
        .list([
            VerificationKeyWitness(
                vkey: .verificationKey(try VerificationKey(payload: Data(repeating: 0x01, count: 32))),
                signature: Data(repeating: 0x02, count: 64))
        ])
    }

    @Test("Redeemers and datums keep bytes decoding cannot hold", arguments: [
        // An indefinite-length redeemer list, its datum a 1 written in two bytes.
        ("05", "9f840000180182" + "0000ff"),
        // A redeemer map whose execution units are written wide.
        ("05", "a1820000821801821a000000011a00000002"),
        // Datums as an indefinite-length set.
        ("04", "d901029f1801ff"),
    ])
    func keepsBytes(key: String, value: String) throws {
        let witnessSet = "a1" + key + value
        let unsigned = "84" + (try body().toCBORHex()) + witnessSet + "f5f6"
        var tx = try Transaction.fromCBORHex(unsigned)
        #expect(try tx.transactionWitnessSet.toCBORHex() == witnessSet)

        tx.transactionWitnessSet.vkeyWitnesses = try witness()
        let signed = try tx.toCBORHex()
        #expect(signed.contains(key + value))

        let written = try key == "05"
            ? tx.transactionWitnessSet.redeemersCBOR() : tx.transactionWitnessSet.plutusDataCBOR()
        #expect(written?.toHex == value)
    }

    @Test("Changed redeemers are encoded afresh")
    func changedRedeemers() throws {
        var witnessSet = try TransactionWitnessSet.fromCBORHex("a1059f840000180182" + "0000ff")
        #expect(try witnessSet.redeemersCBOR()?.toHex == "9f8400001801820000ff")
        let redeemers = witnessSet.redeemers
        witnessSet.redeemers = redeemers
        #expect(try witnessSet.redeemersCBOR()?.toHex == "8184000001820000")
    }

    @Test("A transaction whose Plutus data repeats a map key decodes and keeps its bytes")
    func duplicateKeysInTransaction() throws {
        // A witness datum {1: 2, 1: 3}, which the ledger reads as a list of pairs.
        let unsigned = "84" + (try body().toCBORHex()) + "a10481a201020103" + "f5f6"
        var tx = try Transaction.fromCBORHex(unsigned)
        #expect(try tx.toCBORHex() == unsigned)

        tx.transactionWitnessSet.vkeyWitnesses = try witness()
        #expect(try tx.toCBORHex().contains("0481a201020103"))
    }

    @Test("An inline datum that repeats a map key decodes")
    func duplicateKeysInInlineDatum() throws {
        let input = "825820" + String(repeating: "11", count: 32) + "00"
        // {0: address, 1: 5 ADA, 2: [1, #6.24(h'a201020103')]}
        let output = "a300581d60" + String(repeating: "aa", count: 28) + "011a004c4b40"
            + "028201d81845a201020103"
        let body = "a300d9010281" + input + "0181" + output + "021a00030d40"
        let unsigned = "84" + body + "a0f5f6"

        let tx = try Transaction.fromCBORHex(unsigned)
        #expect(try tx.toCBORHex() == unsigned)
        #expect(tx.transactionBody.id.payload == (try Hash().blake2b(
            data: body.hexStringToData, digestSize: TRANSACTION_HASH_SIZE, encoder: RawEncoder.self)))
    }

    @Test("A body with a long inline datum keeps its hash through a round trip")
    func bodyHashStable() throws {
        let body = try body()
        let unsigned = try Transaction(
            transactionBody: body, transactionWitnessSet: TransactionWitnessSet()
        ).toCBORHex()

        #expect(unsigned.contains("5f5840"))
        let restored = try Transaction.fromCBORHex(unsigned)
        #expect(try restored.toCBORHex() == unsigned)
        #expect(restored.transactionBody.hash() == body.hash())
    }
}
