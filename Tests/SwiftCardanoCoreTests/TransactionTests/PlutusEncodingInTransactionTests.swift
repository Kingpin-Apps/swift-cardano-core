import Foundation
import OrderedCollections
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
