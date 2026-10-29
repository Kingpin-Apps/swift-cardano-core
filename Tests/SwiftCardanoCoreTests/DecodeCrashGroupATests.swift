import BigInt
import Testing
import Foundation
import CBORCodable
import OrderedCollections
@testable import SwiftCardanoCore

/// Inputs that used to crash the process while decoding transactions,
/// outputs, values and addresses. Each must now throw, or decode when the
/// ledger accepts it.
@Suite struct DecodeCrashGroupATests {

    /// Bytes from hex, ignoring spaces.
    func hex(_ string: String) throws -> Data {
        try #require(Data(hexString: string.replacingOccurrences(of: " ", with: "")))
    }

    let zeros32 = String(repeating: "00", count: 32)
    let zeros28 = String(repeating: "00", count: 28)

    /// A JSON string for a dictionary whose values are written as given.
    func json(_ pairs: [(String, String)]) -> String {
        "{" + pairs.map { "\"\($0.0)\":\($0.1)" }.joined(separator: ",") + "}"
    }

    // MARK: - TransactionInput

    @Test func transactionInputWithTooFewElementsThrows() throws {
        // inputs = [[]]
        #expect(throws: (any Error).self) {
            _ = try TransactionBody.fromCBOR(data: try hex("a3 00 81 80 01 80 02 00"))
        }
        #expect(throws: (any Error).self) { _ = try TransactionInput.fromCBOR(data: try hex("80")) }
        #expect(throws: (any Error).self) {
            _ = try TransactionInput.fromCBOR(data: try hex("81 5820 \(zeros32)"))
        }
    }

    @Test func transactionInputIndexAboveUInt16Throws() throws {
        #expect(throws: (any Error).self) {
            _ = try TransactionInput.fromCBOR(data: try hex("82 5820 \(zeros32) 1a00010000"))
        }
        #expect(throws: (any Error).self) {
            _ = try TransactionInput.fromCBOR(data: try hex("82 5820 \(zeros32) 20"))
        }
        let input = try TransactionInput.fromCBOR(data: try hex("82 5820 \(zeros32) 19ffff"))
        #expect(input.index == UInt16.max)
    }

    @Test func transactionInputJSONIndexOutOfRangeThrows() throws {
        for index in ["70000", "-1", "18446744073709551615"] {
            #expect(throws: (any Error).self) {
                _ = try TransactionInput.fromJSON(
                    json([("transactionId", "\"\(zeros32)\""), ("index", index)]))
            }
        }
        let input = try TransactionInput.fromJSON(
            json([("transactionId", "\"\(zeros32)\""), ("index", "65535")]))
        #expect(input.index == 65535)
    }

    // MARK: - Shelley outputs

    @Test func shelleyOutputWithTooFewElementsThrows() throws {
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: try hex("80")) }
        #expect(throws: (any Error).self) {
            _ = try TransactionOutput.fromCBOR(data: try hex("81 581d 60 \(zeros28)"))
        }
    }

    @Test func shelleyOutputJSONAmountOutOfRangeThrows() throws {
        let address = try Address(
            paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: 28))),
            network: .testnet
        ).toBech32()
        for amount in ["18446744073709551616", "-1"] {
            #expect(throws: (any Error).self) {
                _ = try ShelleyTransactionOutput.fromJSON(
                    json([("address", "\"\(address)\""), ("amount", amount)]))
            }
            #expect(throws: (any Error).self) {
                _ = try ShelleyTransactionOutput.fromJSON(
                    json([("address", "\"\(address)\""), ("amount", "{\"coin\":\(amount)}")]))
            }
        }
        let output = try ShelleyTransactionOutput.fromJSON(
            json([("address", "\"\(address)\""), ("amount", "9223372036854775807")]))
        #expect(output.amount.coin == BigInt(Int64.max))
    }

    @Test func shelleyOutputToDictWithNegativeCoinDoesNotTrap() throws {
        let address = try Address(
            paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: 28))),
            network: .testnet)
        // A negative coin encodes without trapping; reading it back fails, as
        // an output coin is unsigned.
        let output = ShelleyTransactionOutput(address: address, amount: Value(coin: -1))
        #expect(throws: (any Error).self) { _ = try ShelleyTransactionOutput.fromDict(output.toDict()) }
    }

    // MARK: - Babbage outputs

    @Test func babbageOutputWithoutAddressOrAmountThrows() throws {
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: try hex("a2 05 00 06 00")) }
        #expect(throws: (any Error).self) {
            _ = try TransactionOutput.fromCBOR(data: try hex("a2 00 581d 60 \(zeros28) 06 00"))
        }
        let output = try TransactionOutput.fromCBOR(data: try hex("a2 00 581d 60 \(zeros28) 01 00"))
        #expect(output.amount.coin == 0)
    }

    @Test func babbageOutputJSONAmountOutOfRangeThrows() throws {
        let address = try Address(
            paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: 28))),
            network: .testnet
        ).toBech32()
        for amount in ["18446744073709551616", "-1"] {
            #expect(throws: (any Error).self) {
                _ = try BabbageTransactionOutput.fromJSON(
                    json([("address", "\"\(address)\""), ("amount", amount)]))
            }
        }
    }

    @Test func babbageOutputToDictWithNegativeCoinDoesNotTrap() throws {
        let address = try Address(
            paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: 28))),
            network: .testnet)
        let output = BabbageTransactionOutput(address: address, amount: Value(coin: -1))
        #expect(throws: (any Error).self) { _ = try BabbageTransactionOutput.fromDict(output.toDict()) }
    }

    // MARK: - Value and Asset

    @Test func valueCoinOutsideWord64Throws() throws {
        // An output coin is a Word64 (`decodeWord64`): above Int64.max decodes,
        // a negative coin does not.
        #expect(try Value.fromCBOR(data: try hex("1b8000000000000000")).coin == BigInt(Int64.max) + 1)
        #expect(try Value.fromCBOR(data: try hex("82 1bffffffffffffffff a0")).coin == BigInt(UInt64.max))
        #expect(throws: (any Error).self) { _ = try Value.fromCBOR(data: try hex("3b8000000000000000")) }
        #expect(throws: (any Error).self) { _ = try Value.fromCBOR(data: try hex("20")) }
        #expect(try Value.fromCBOR(data: try hex("1b7fffffffffffffff")).coin == BigInt(Int64.max))
        #expect(try Value(from: Value(coin: 5).toPrimitive()).coin == 5)
    }

    @Test func assetAmountAboveInt64Throws() throws {
        #expect(throws: (any Error).self) { _ = try Asset.fromCBOR(data: try hex("a1 40 1bffffffffffffffff")) }
        #expect(throws: (any Error).self) { _ = try Asset.fromCBOR(data: try hex("a1 40 3bffffffffffffffff")) }
        // JSON amounts are unbounded: Asset holds sums and differences too.
        #expect(try Asset.fromJSON(#"{"":18446744073709551615}"#).data.values.first == BigInt(UInt64.max))
        let asset = try Asset.fromCBOR(data: try hex("a1 40 3b7fffffffffffffff"))
        #expect(asset.data.values.first == BigInt(Int64.min))
    }

    // MARK: - Withdrawals

    @Test func withdrawalsJSONNegativeAmountThrows() throws {
        #expect(throws: (any Error).self) { _ = try Withdrawals.fromJSON(#"{"00":-1}"#) }
    }

    @Test func withdrawalsAboveInt64RoundTripThroughJSON() throws {
        let account = Data([0xe0] + Array(repeating: 0, count: 28))
        let withdrawals = Withdrawals([account: Coin.max])
        let dict = try withdrawals.toDict()
        #expect(try Withdrawals.fromDict(dict) == withdrawals)

        let decoded = try Withdrawals.fromCBOR(
            data: try hex("a1 581d e0 \(zeros28) 1bffffffffffffffff"))
        #expect(decoded[account] == Coin.max)
        #expect(throws: (any Error).self) {
            _ = try Withdrawals.fromCBOR(data: try hex("a1 581d e0 \(zeros28) 20"))
        }
    }

    // MARK: - Datums

    @Test func datumOptionWithTooFewElementsThrows() throws {
        #expect(throws: (any Error).self) { _ = try DatumOption.fromCBOR(data: try hex("80")) }
        #expect(throws: (any Error).self) { _ = try DatumOption.fromCBOR(data: try hex("8100")) }
        #expect(throws: (any Error).self) { _ = try DatumOption.fromCBOR(data: try hex("8101")) }
    }

    @Test func rawDatumIntegerAboveIntIsPlutusData() throws {
        let datum = try RawDatum(from: Primitive.uint(UInt64.max))
        guard case .plutusData = datum else {
            Issue.record("expected Plutus data, got \(datum)")
            return
        }
        let negative = try RawDatum(from: Primitive.int(-5))
        #expect(negative == .int(-5))
    }

    @Test func rawDatumListWithNullDoesNotCrash() throws {
        // [null] is not Plutus data.
        #expect(throws: (any Error).self) { _ = try RawDatum.fromCBOR(data: try hex("81 f6")) }
    }

    // MARK: - IndefiniteList

    @Test func indefiniteListOfWrongElementTypeThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try IndefiniteList<String>(from: Primitive.list([.int(1)]))
        }
        #expect(throws: (any Error).self) {
            _ = try IndefiniteList<AnyValue>.fromCBOR(data: try hex("81 f6"))
        }
        #expect(throws: (any Error).self) {
            _ = try IndefiniteList<String>.fromCBOR(data: try hex("9f 01 ff"))
        }
        let list = try IndefiniteList<Primitive>(from: Primitive.list([.int(1)]))
        #expect(list.count == 1)
    }

    // MARK: - ScriptRef

    @Test func scriptRefJSONNegativeTagThrows() throws {
        #expect(throws: (any Error).self) { _ = try ScriptRef.fromJSON(#"{"tag":-1,"value":""}"#) }
        #expect(throws: (any Error).self) {
            _ = try ScriptRef.fromJSON(#"{"tag":18446744073709551615,"value":""}"#)
        }
        // A plutus V2 script `[2, h'00']` under a tag other than 24.
        #expect(throws: (any Error).self) { _ = try ScriptRef(tag: 25, value: .bytes(try hex("82 02 41 00"))) }
        let ref = try ScriptRef(tag: 24, value: .bytes(try hex("82 02 41 00")))
        #expect(try ScriptRef.fromDict(ref.toDict()) == ref)
    }

    @Test func scriptWithHugeTypeThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try ScriptRef(tag: 24, value: .bytes(try hex("82 1bffffffffffffffff 40")))
        }
    }

    // MARK: - VerificationKeyWitness

    @Test func verificationKeyWitnessFromBadPayloadThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try VerificationKeyWitness(payload: Data([0x00]), type: nil, description: nil)
        }
    }

    // MARK: - Address

    @Test func shortPointerAddressThrows() throws {
        #expect(throws: (any Error).self) { _ = try Address.fromCBOR(data: try hex("42 4100")) }
        #expect(throws: (any Error).self) { _ = try Address(from: .bytes(try hex("41 \(zeros28)"))) }
        #expect(throws: (any Error).self) { _ = try Address(from: .bytes(try hex("41 \(zeros28) 00"))) }
        let pointer = try Address(from: .bytes(try hex("41 \(zeros28) 01 02 03")))
        guard case .pointerAddress(let p) = pointer.stakingPart else {
            Issue.record("expected a pointer address")
            return
        }
        #expect(p == PointerAddress(slot: 1, txIndex: 2, certIndex: 3))
    }

    @Test func addressWithWrongHashLengthThrows() throws {
        // Base address with one byte, enterprise address with 27, and a
        // base address with a trailing byte.
        #expect(throws: (any Error).self) { _ = try Address(from: .bytes(try hex("01 00"))) }
        #expect(throws: (any Error).self) {
            _ = try Address(from: .bytes(try hex("61 \(String(repeating: "00", count: 27))")))
        }
        #expect(throws: (any Error).self) {
            _ = try Address(from: .bytes(try hex("01 \(zeros28) \(zeros28) 00")))
        }
        let base = try Address(from: .bytes(try hex("01 \(zeros28) \(zeros28)")))
        #expect(base.toBytes().count == 57)
    }

    // MARK: - StakeAddressInfo

    @Test func stakeAddressInfoWithoutAddressThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(StakeAddressInfo.self, from: Data("{}".utf8))
        }
    }
}
