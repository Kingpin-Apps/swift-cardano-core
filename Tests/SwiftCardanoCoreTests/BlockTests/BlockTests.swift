import Testing
import Foundation
import PotentCBOR
import OrderedCollections
@testable import SwiftCardanoCore

func makeBlock(
    includeTxs: Bool = true,
    includeAuxData: Bool = false,
    includeInvalidTxs: Bool = false
) throws -> Block {
    let header = try makeHeader()

    var transactionBodies: [TransactionBody] = []
    var transactionWitnessSets: [TransactionWitnessSet] = []
    var auxiliaryDataSet = OrderedDictionary<TransactionIndex, AuxiliaryData>()
    var invalidTransactions: [TransactionIndex] = []

    if includeTxs {
        let txBody = try makeTransactionBody()
        transactionBodies = [txBody]

        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: nil,
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        transactionWitnessSets = [witnessSet]
    }

    if includeAuxData {
        let metadata = try Metadata([1: .int(42)])
        let auxData = AuxiliaryData(data: .metadata(metadata))
        auxiliaryDataSet[0] = auxData
    }

    if includeInvalidTxs {
        invalidTransactions = [0]
    }

    return Block(
        header: header,
        transactionBodies: transactionBodies,
        transactionWitnessSets: transactionWitnessSets,
        auxiliaryDataSet: auxiliaryDataSet,
        invalidTransactions: invalidTransactions
    )
}

@Suite struct BlockTests {
    @Test func testInitialization() async throws {
        let header = try makeHeader()
        let block = Block(
            header: header,
            transactionBodies: [],
            transactionWitnessSets: [],
            auxiliaryDataSet: [:],
            invalidTransactions: []
        )

        #expect(block.header == header)
        #expect(block.transactionBodies.isEmpty)
        #expect(block.transactionWitnessSets.isEmpty)
        #expect(block.auxiliaryDataSet.isEmpty)
        #expect(block.invalidTransactions.isEmpty)
    }

    @Test func testEmptyBlockPrimitiveRoundTrip() async throws {
        let header = try makeHeader()
        let block = Block(
            header: header,
            transactionBodies: [],
            transactionWitnessSets: []
        )

        let primitive = try block.toPrimitive()
        let restored = try Block(from: primitive)
        #expect(restored == block)
    }

    @Test func testBlockWithTransactionsCBORRoundTrip() async throws {
        let block = try makeBlock(includeTxs: true)
        let cborData = try block.toCBORData()
        let restored = try Block.fromCBOR(data: cborData)
        #expect(restored == block)
    }

    @Test func testBlockWithInvalidTransactions() async throws {
        let block = try makeBlock(includeTxs: true, includeInvalidTxs: true)
        #expect(block.invalidTransactions == [0])

        let cborData = try block.toCBORData()
        let restored = try Block.fromCBOR(data: cborData)
        #expect(restored.invalidTransactions == [0])
    }

    @Test func testPrimitiveStructure() async throws {
        let block = try makeBlock(includeTxs: true)
        let primitive = try block.toPrimitive()

        guard case let .list(elements) = primitive else {
            Issue.record("Expected .list primitive")
            return
        }

        #expect(elements.count == 5)

        // header (list with 2 elements)
        guard case .list = elements[0] else {
            Issue.record("Expected .list for header")
            return
        }

        // transaction_bodies (list)
        guard case let .list(txBodies) = elements[1] else {
            Issue.record("Expected .list for transaction_bodies")
            return
        }
        #expect(txBodies.count == 1)

        // transaction_witness_sets (list)
        guard case let .list(txWitnesses) = elements[2] else {
            Issue.record("Expected .list for transaction_witness_sets")
            return
        }
        #expect(txWitnesses.count == 1)

        // auxiliary_data_set (dict)
        guard case let .orderedDict(auxDict) = elements[3] else {
            Issue.record("Expected .orderedDict for auxiliary_data_set")
            return
        }
        #expect(auxDict.count == 0)

        // invalid_transactions (list)
        guard case let .list(invalidTxs) = elements[4] else {
            Issue.record("Expected .list for invalid_transactions")
            return
        }
        #expect(invalidTxs.count == 0)
    }

    @Test func testCBORRoundTripEmptyBlock() async throws {
        let header = try makeHeader()
        let block = Block(
            header: header,
            transactionBodies: [],
            transactionWitnessSets: []
        )
        try checkTwoWayCBOR(serializable: block)
    }

    @Test func testCBORRoundTripWithTransactions() async throws {
        let block = try makeBlock(includeTxs: true)
        try checkTwoWayCBOR(serializable: block)
    }

    @Test func testJSONRoundTripEmptyBlock() async throws {
        let header = try makeHeader()
        let block = Block(
            header: header,
            transactionBodies: [],
            transactionWitnessSets: []
        )
        let dict = try block.toDict()
        let restored = try Block.fromDict(dict)
        #expect(restored == block)
    }

    @Test func testJSONRoundTripWithTransactions() async throws {
        let block = try makeBlock(includeTxs: true)
        let dict = try block.toDict()
        let restored = try Block.fromDict(dict)
        #expect(restored == block)
    }

    @Test func testEquality() async throws {
        let block1 = try makeBlock(includeTxs: true)
        let block2 = try makeBlock(includeTxs: true)
        #expect(block1 == block2)

        let emptyBlock = try makeBlock(includeTxs: false)
        #expect(block1 != emptyBlock)
    }

    @Test func testDefaultParameters() async throws {
        let header = try makeHeader()
        let block = Block(
            header: header,
            transactionBodies: [],
            transactionWitnessSets: []
        )
        #expect(block.auxiliaryDataSet.isEmpty)
        #expect(block.invalidTransactions.isEmpty)
    }
}
