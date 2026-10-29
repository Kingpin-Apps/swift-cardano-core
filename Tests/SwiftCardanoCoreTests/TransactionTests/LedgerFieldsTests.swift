import Foundation
import Testing

@testable import SwiftCardanoCore

/// Each era's ledger reads only the record fields its CDDL defines.
@Suite("Record fields follow each era's CDDL")
struct LedgerFieldsTests {
    static let input = "825820" + String(repeating: "11", count: 32) + "00"
    static let output = "82581d60" + String(repeating: "aa", count: 28) + "1a004c4b40"
    static let genesisHash = "581c" + String(repeating: "cc", count: 28)

    func body(_ extra: String, fields: Int) -> String {
        String(format: "a%x", fields) + "0081" + Self.input + "0181" + Self.output + "021a00030d40" + extra
    }

    func decodes(_ body: String, in era: Era) -> Bool {
        (try? TransactionBody.fromCBOR(data: body.hexStringToData, era: era)) != nil
    }

    @Test("A body field an era does not define is rejected in that era")
    func bodyFields() {
        // 6: update [{genesis hash => {12: d}}, epoch], gone from Conway.
        let update = "0682a1" + Self.genesisHash + "a10cd81e820102" + "00"
        let withUpdate = body(update, fields: 4)
        #expect(decodes(withUpdate, in: .shelley))
        #expect(!decodes(withUpdate, in: .conway))

        // 8: validity start, from Allegra.
        let withStart = body("0800", fields: 4)
        #expect(!decodes(withStart, in: .shelley))
        #expect(decodes(withStart, in: .allegra))

        // 19: voting procedures, from Conway.
        let withVotes = body("13a0", fields: 4)
        #expect(!decodes(withVotes, in: .babbage))
    }

    @Test("A parameter update holds only its era's keys")
    func updateKeys() {
        // 12 (decentralisation) is gone from Babbage.
        let update = "0682a1" + Self.genesisHash + "a10cd81e820102" + "00"
        #expect(decodes(body(update, fields: 4), in: .alonzo))
        #expect(!decodes(body(update, fields: 4), in: .babbage))
    }

    @Test("A Conway parameter change cannot carry the protocol version")
    func conwayKeys() throws {
        // [0, null, {14: [10, 0]}, null]
        #expect(throws: CardanoCoreError.self) { try ParameterChangeAction.fromCBORHex("8400f6a10e820a00f6") }
        #expect(try ParameterChangeAction.fromCBORHex("8400f6a1001901f4f6").protocolParamUpdate.minFeeA == 500)
    }
}
