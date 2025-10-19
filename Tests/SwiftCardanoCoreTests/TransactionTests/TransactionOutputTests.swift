import Testing
import PotentCBOR
@testable import SwiftCardanoCore

struct TransactionOutputTests {
    @Test func testInitialization() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        
        let output = TransactionOutput(
            address: address,
            amount: amount
        )
        
        #expect(output.address == address)
        #expect(output.amount == amount)
        #expect(output.lovelace == 1000000)
        #expect(output.datumHash == nil)
        #expect(output.datumOption == nil)
        #expect(output.script == nil)
        #expect(output.postAlonzo == false)
    }
    
    @Test
    func testInitializationFromStrings() throws {
        let output = try TransactionOutput(
            from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            amount: 1000000
        )
        
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        
        #expect(output.address == address)
        #expect(output.lovelace == 1000000)
        #expect(output.datumHash == nil)
        #expect(output.datumOption == nil)
        #expect(output.script == nil)
    }
    
    @Test
    func testValidation() throws {
        // Test valid output
        let validOutput = try TransactionOutput(
            from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            amount: 1000000
        )
        try validOutput.validate()
        
        // Test negative ADA amount
        let negativeOutput = try TransactionOutput(
            from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n",
            amount: -1000000
        )
        #expect(throws: CardanoCoreError.self) {
            try negativeOutput.validate()
        }
    }
    
    @Test
    func testEquality() throws {
        let address = "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"
        let output1 = try TransactionOutput(
            from: address,
            amount: 1000000
        )
        
        let output2 = try TransactionOutput(
            from: address,
            amount: 1000000
        )
        
        let output3 = try TransactionOutput(
            from: address,
            amount: 2000000
        )
        
        #expect(output1 == output2)
        #expect(output1 != output3)
    }
    
    @Test
    func testCodingBabbage() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        
        let output = TransactionOutput(
            address: address,
            amount: amount,
            postAlonzo: false
        )
        
        let encoded = try CBOREncoder().encode(output)
        let decoded = try CBORDecoder().decode(TransactionOutput.self, from: encoded)
        
        #expect(output == decoded)
    }
    
    @Test
    func testCodingPreBabbage() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        
        let output = TransactionOutput(
            address: address,
            amount: amount,
            postAlonzo: false
        )
        
        let encoded = try CBOREncoder().encode(output)
        let decoded = try CBORDecoder().decode(TransactionOutput.self, from: encoded)
        
        #expect(output.address == decoded.address)
        #expect(output.amount == decoded.amount)
    }
} 
