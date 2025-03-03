import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("Transaction Tests")
struct TransactionTests {
    // Test data
    let transactionId = try! TransactionId(
        from: "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
    )
    let address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
    let amount = Value(coin: 1000000)
    let verificationKey = VKey(payload: Data(repeating: 0x01, count: 64))
    let signature = Data(repeating: 0x03, count: 64)
    
    @Test("Test initialization with required parameters")
    func testRequiredParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: [input],
            outputs: [output],
            fee: fee
        )
        
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: [vkeyWitness],
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet
        )
        
        #expect(transaction.transactionBody == body)
        #expect(transaction.transactionWitnessSet == witnessSet)
        #expect(transaction.valid == true)
        #expect(transaction.auxiliaryData == nil)
        #expect(transaction.id == body.id)
    }
    
    @Test("Test initialization with all parameters")
    func testAllParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: [input],
            outputs: [output],
            fee: fee
        )
        
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: [vkeyWitness],
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        let auxiliaryData = try AuxiliaryData(data:.metadata(Metadata([1: .int(42)])))
        
        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet,
            valid: false,
            auxiliaryData: auxiliaryData
        )
        
        #expect(transaction.transactionBody == body)
        #expect(transaction.transactionWitnessSet == witnessSet)
        #expect(transaction.valid == false)
        #expect(transaction.auxiliaryData == auxiliaryData)
        #expect(transaction.id == body.id)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: [input],
            outputs: [output],
            fee: fee
        )
        
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: [vkeyWitness],
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        let auxiliaryData = try AuxiliaryData(
            data:.metadata(Metadata([1: .int(42)]))
        )
        
        let originalTransaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet,
            valid: false,
            auxiliaryData: auxiliaryData
        )
        
        let encodedData = try CBOREncoder().encode(originalTransaction)
        let decodedTransaction = try CBORDecoder().decode(Transaction.self, from: encodedData)
        
        #expect(decodedTransaction == originalTransaction)
        #expect(decodedTransaction.transactionBody == originalTransaction.transactionBody)
        #expect(decodedTransaction.transactionWitnessSet == originalTransaction.transactionWitnessSet)
        #expect(decodedTransaction.valid == originalTransaction.valid)
        #expect(decodedTransaction.auxiliaryData == originalTransaction.auxiliaryData)
        #expect(decodedTransaction.id == originalTransaction.id)
    }
    
    @Test("Test transaction ID generation")
    func testTransactionId() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: [input],
            outputs: [output],
            fee: fee
        )
        
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: [vkeyWitness],
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet
        )
        
        let id = transaction.id
        #expect(id?.payload.count == TRANSACTION_HASH_SIZE)
        #expect(id == body.id)
    }
} 
