import Foundation
import OrderedCollections
import Testing
@testable import SwiftCardanoCore

@Suite struct PositiveCoinTests {
    @Test("A positive coin survives a CBOR round trip")
    func roundTrip() throws {
        let coin = PositiveCoin(1_000_000)
        #expect(try PositiveCoin.fromCBOR(data: coin.toCBORData()) == coin)
    }

    @Test("Zero and negative values are refused, not trapped on")
    func refused() {
        #expect(throws: CardanoCoreError.self) { try PositiveCoin(from: .uint(0)) }
        #expect(throws: CardanoCoreError.self) { try PositiveCoin(from: .int(-5)) }
    }

    @Test("A transaction body with a treasury donation decodes from its CBOR")
    func bodyWithDonation() throws {
        let input = TransactionInput(transactionId: TransactionId(payload: Data(repeating: 0xAA, count: 32)), index: 0)
        let address = try Address(
            paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0x01, count: 28))),
            network: .testnet
        )
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [TransactionOutput(address: address, amount: Value(coin: 2_000_000))],
            fee: 200_000,
            treasuryDonation: PositiveCoin(1_000_000)
        )
        let decoded = try TransactionBody.fromCBOR(data: body.toCBORData())
        #expect(decoded.treasuryDonation == PositiveCoin(1_000_000))
    }
}
