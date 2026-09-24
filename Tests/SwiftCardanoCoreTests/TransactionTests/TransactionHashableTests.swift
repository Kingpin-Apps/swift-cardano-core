import Foundation
import Testing

@testable import SwiftCardanoCore

/// Anything that says two values are equal has to hash them alike, or one of them
/// goes missing from a `Set` or a dictionary.
///
/// A transaction and its body compare their own fields and deliberately ignore
/// the text-envelope payload, but they inherited a `hash(into:)` that hashed only
/// that payload — so a body loaded from a file and the same body decoded from CBOR
/// compared equal and hashed differently.
@Suite("Transactions hash the way they compare")
struct TransactionHashableTests {

    private func body(fee: Coin = 7) -> TransactionBody {
        TransactionBody(
            inputs: .list([
                TransactionInput(
                    transactionId: TransactionId(payload: Data(repeating: 0xAA, count: 32)),
                    index: 0
                )
            ]),
            outputs: [],
            fee: fee
        )
    }

    @Test("A body's payload does not change its hash, because it does not change equality")
    func bodyIgnoresPayload() {
        let plain = body()
        var loaded = plain
        loaded._payload = Data([0x01, 0x02])
        #expect(plain == loaded)
        #expect(plain.hashValue == loaded.hashValue)
        #expect(Set([plain, loaded]).count == 1)
    }

    @Test("A body's field order does not change its hash either")
    func bodyIgnoresFieldOrder() {
        let plain = body()
        var reordered = plain
        reordered.writtenFieldOrder = [2, 1, 0]
        #expect(plain == reordered)
        #expect(plain.hashValue == reordered.hashValue)
    }

    @Test("Bodies that differ still land in different buckets")
    func differentBodiesDiffer() {
        #expect(body(fee: 7) != body(fee: 9))
        #expect(body(fee: 7).hashValue != body(fee: 9).hashValue)
    }

    @Test("A transaction follows its body")
    func transactionIgnoresPayload() {
        let plain = Transaction(
            transactionBody: body(), transactionWitnessSet: TransactionWitnessSet()
        )
        var loaded = plain
        loaded._payload = Data([0x03])
        #expect(plain == loaded)
        #expect(plain.hashValue == loaded.hashValue)
        #expect(Set([plain, loaded]).count == 1)
    }
}
