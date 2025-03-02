import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("UTxO Tests")
struct UTxOTests {
    // Test data
    let transactionId = try! TransactionId(
        from: "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
    )
    let index: UInt16 = 1
    let address: Address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
    let amount = Value(coin: 1000000)
    
    @Test("Initialize UTxO with valid parameters")
    func testInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: index)
        let output = TransactionOutput(address: address, amount: amount)
        let utxo = UTxO(input: input, output: output)
        
        #expect(utxo.input == input)
        #expect(utxo.output == output)
    }
    
    @Test("Initialize UTxO from primitives")
    func testInitializationFromPrimitives() throws {
        let inputPrimitives = ("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5", index)
        let outputPrimitives = ("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
                                1000000,
                                Datum?.none,
                                ScriptType?.none,
                                true)
        let utxo = try UTxO(
            from: inputPrimitives,
            outputPrimitives: outputPrimitives
        )
        
        let input = try TransactionInput(from: inputPrimitives.0, index: inputPrimitives.1)
        let output = try TransactionOutput(from: outputPrimitives.0,
                                   amount: outputPrimitives.1,
                                   datum: outputPrimitives.2,
                                   script: outputPrimitives.3,
                                   postAlonzo: outputPrimitives.4)
        
        #expect(utxo.input == input)
        #expect(utxo.output == output)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let input = TransactionInput(transactionId: transactionId, index: index)
        let output = TransactionOutput(address: address, amount: amount)
        let originalUtxo = UTxO(input: input, output: output)
        
        let encodedData = try CBOREncoder().encode(originalUtxo)
        let decodedUtxo = try CBORDecoder().decode(UTxO.self, from: encodedData)
        
        #expect(decodedUtxo == originalUtxo)
        #expect(decodedUtxo.input == originalUtxo.input)
        #expect(decodedUtxo.output == originalUtxo.output)
    }
    
    @Test("Test Hashable conformance")
    func testHashable() throws {
        let input1 = TransactionInput(transactionId: transactionId, index: index)
        let output1 = TransactionOutput(address: address, amount: amount)
        let utxo1 = UTxO(input: input1, output: output1)
        
        let input2 = TransactionInput(transactionId: transactionId, index: index)
        let output2 = TransactionOutput(address: address, amount: amount)
        let utxo2 = UTxO(input: input2, output: output2)
        
        let differentTransactionId = try TransactionId(
            from: "c1b58dd4f2f4ee8656cc7962eefa8552877c4aa23d0699c02b885363d592a961"
        )
        let input3 = TransactionInput(transactionId: differentTransactionId, index: index)
        let output3 = TransactionOutput(address: address, amount: amount)
        let utxo3 = UTxO(input: input3, output: output3)
        
        #expect(utxo1 == utxo2)
        #expect(utxo1 != utxo3)
        
        var set = Set<UTxO>()
        set.insert(utxo1)
        
        #expect(set.contains(utxo2))
        #expect(!set.contains(utxo3))
    }
    
    @Test("Test description")
    func testDescription() throws {
        let input = TransactionInput(transactionId: transactionId, index: index)
        let output = TransactionOutput(address: address, amount: amount)
        let utxo = UTxO(input: input, output: output)
        
        let expectedDescription = "\(input) -> \(output)"
        #expect(utxo.description == expectedDescription)
    }
} 
