import Foundation
import Testing

@testable import SwiftCardanoCore

/// A repeated map key or set element is read as the ledger of the era reads
/// it: kept once before Conway, rejected from Conway, except where the ledger
/// still allows it.
@Suite("Repeated keys follow the ledger's rules")
struct LedgerDuplicateRulesTests {
    static let input = "825820" + String(repeating: "11", count: 32) + "00"
    static let otherInput = "825820" + String(repeating: "11", count: 32) + "01"
    static let output = "82581d60" + String(repeating: "aa", count: 28) + "1a004c4b40"
    static let rewardAccount = "581de0" + String(repeating: "bb", count: 28)
    static let witness = "825820" + String(repeating: "01", count: 32) + "5840" + String(repeating: "02", count: 64)

    func body(inputs: String = "81" + input, extra: String = "", fields: Int = 3) -> String {
        String(format: "a%x", fields) + "00" + inputs + "0181" + Self.output + "021a00030d40" + extra
    }

    func tx(body: String? = nil, witnessSet: String = "a0", auxiliaryData: String = "f6") -> String {
        "84" + (body ?? self.body()) + witnessSet + "f5" + auxiliaryData
    }

    func decodes(_ hex: String, in era: Era) -> Bool {
        (try? Transaction.fromCBOR(data: hex.hexStringToData, era: era)) != nil
    }

    @Test("A body that repeats a field is rejected in every era")
    func repeatedBodyField() {
        let hex = tx(body: body(extra: "021a00030d41", fields: 4))
        #expect(!decodes(hex, in: .babbage))
        #expect(!decodes(hex, in: .conway))
    }

    @Test("A map that repeats a key: kept with its later value before Conway, rejected from it")
    func repeatedWithdrawal() throws {
        let withdrawals = "05a2" + Self.rewardAccount + "01" + Self.rewardAccount + "02"
        let hex = tx(body: body(extra: withdrawals, fields: 4))
        #expect(!decodes(hex, in: .conway))
        let tx = try Transaction.fromCBOR(data: hex.hexStringToData, era: .babbage)
        #expect(tx.transactionBody.withdrawals?.data.values.first == 2)
        #expect(try tx.toCBORHex() == hex)
    }

    @Test("A set that repeats an element: kept once before Conway, rejected from it")
    func repeatedInput() throws {
        #expect(!decodes(tx(body: body(inputs: "d9010282" + Self.input + Self.input)), in: .conway))
        #expect(!decodes(tx(body: body(inputs: "82" + Self.input + Self.input)), in: .conway))
        let hex = tx(body: body(inputs: "82" + Self.input + Self.input))
        #expect(try Transaction.fromCBOR(data: hex.hexStringToData, era: .babbage).toCBORHex() == hex)
        #expect(decodes(tx(body: body(inputs: "d9010282" + Self.input + Self.otherInput)), in: .conway))
    }

    @Test("Conway still allows repeated key witnesses and redeemer keys")
    func conwayExceptions() throws {
        #expect(decodes(tx(witnessSet: "a10082" + Self.witness + Self.witness), in: .conway))

        // {[spend, 0]: [0, [0, 0]], [spend, 0]: [1, [0, 0]]}
        let hex = tx(witnessSet: "a105a2820000820082000082000082018200" + "00")
        let tx = try Transaction.fromCBOR(data: hex.hexStringToData, era: .conway)
        guard case .map(let redeemers) = tx.transactionWitnessSet.redeemers else {
            Issue.record("expected a redeemer map")
            return
        }
        #expect(redeemers[RedeemerKey(tag: .spend, index: 0)]?.data == .bigInt(.int(1)))
        #expect(try tx.toCBORHex() == hex)
    }

    @Test("Conway rejects repeated Plutus scripts")
    func repeatedPlutusScripts() {
        #expect(!decodes(tx(witnessSet: "a10382410141" + "01"), in: .conway))
        #expect(decodes(tx(witnessSet: "a10382410141" + "02"), in: .conway))
    }

    @Test("Metadata labels follow the map rule; metadata maps may always repeat a key")
    func metadata() throws {
        #expect(!decodes(tx(auxiliaryData: "a201010102"), in: .conway))
        #expect(decodes(tx(auxiliaryData: "a201010102"), in: .babbage))

        let hex = tx(auxiliaryData: "a101a201020103")
        let decoded = try Transaction.fromCBOR(data: hex.hexStringToData, era: .conway)
        guard case .metadata(let metadata) = decoded.auxiliaryData?.data, case .map(let pairs) = metadata[1]
        else {
            Issue.record("expected a metadata map")
            return
        }
        #expect(pairs.count == 2)
        #expect(try decoded.toCBORHex() == hex)
    }

    @Test("Plutus data may repeat a map key in every era")
    func plutusData() throws {
        let hex = tx(witnessSet: "a10481a201020103")
        for era in [Era.alonzo, .babbage, .conway] {
            let tx = try Transaction.fromCBOR(data: hex.hexStringToData, era: era)
            guard case .list(let datums) = tx.transactionWitnessSet.plutusData,
                case .map(let pairs) = datums.first
            else {
                Issue.record("expected a datum map")
                return
            }
            #expect(pairs.count == 2)
            #expect(try tx.toCBORHex() == hex)
        }
    }
}
