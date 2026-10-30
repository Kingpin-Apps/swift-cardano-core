import Foundation
import Testing

@testable import SwiftCardanoCore

/// Every real transaction of the corpus survives `toJSON()` and `fromJSON()`.
@Suite("Transaction JSON corpus")
struct TransactionJSONCorpusTests {
    @Test("A transaction read back from its JSON is the same transaction", arguments: TransactionCorpusTests.corpus)
    func roundTrip(_ entry: TransactionCorpusTests.Entry) throws {
        let tx = try Transaction.fromCBOR(data: try entry.bytes(), era: entry.ledgerEra)
        let json = try #require(try tx.toJSON())
        let restored = try Transaction.fromJSON(json)
        #expect(restored.transactionBody == tx.transactionBody)
        #expect(restored.transactionWitnessSet == tx.transactionWitnessSet)
        #expect(restored.auxiliaryData == tx.auxiliaryData)
        #expect(restored == tx)
    }
}
