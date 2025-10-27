import Foundation
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
    
    @Test func testTransactionOutput() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        let datumHash = DatumHash(payload: Data(repeating: 0x01, count: 32))
        let datumOption = DatumOption(
            datum: .datumHash(DatumHash(
                payload: Data(repeating: 0x01, count: 32))
            )
        )
        let script: ScriptType = .plutusV3Script(PlutusV3Script(
            data: Data(repeating: 0x02, count: 10))
        )
            
        
        let output1 = TransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash,
            datumOption: datumOption,
            script: script,
            postAlonzo: true
        )
        
        let output2 = TransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash,
            datumOption: datumOption,
            script: script,
            postAlonzo: false
        )
        
        let encoded1 = try JSONEncoder().encode(output1)
        let decoded1 = try JSONDecoder().decode(TransactionOutput.self, from: encoded1)
        let encoded2 = try JSONEncoder().encode(output2)
        let decoded2 = try JSONDecoder().decode(TransactionOutput.self, from: encoded2)
        
        #expect(output1.address == decoded1.address)
        #expect(output1.amount == decoded1.amount)
        #expect(output1.lovelace == decoded1.lovelace)
        #expect(output1.datumHash == decoded1.datumHash)
        #expect(output1.datumOption == decoded1.datumOption)
        #expect(output1.script == decoded1.script)
        #expect(output1.postAlonzo == decoded1.postAlonzo)
        
        #expect(output2.address == decoded2.address)
        #expect(output2.amount == decoded2.amount)
        #expect(output2.lovelace == decoded2.lovelace)
        #expect(output2.datumHash == decoded2.datumHash)
        #expect(output2.datumOption == decoded2.datumOption)
        #expect(output2.script == decoded2.script)
        #expect(output2.postAlonzo == decoded2.postAlonzo)
    }
    
    @Test
    func testTransactionOutputLegacy() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        
        let output = TransactionOutputLegacy(
            address: address,
            amount: amount,
            datumHash: DatumHash(payload: Data(repeating: 0x01, count: 32))
        )
        
        let encoded = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(TransactionOutputLegacy.self, from: encoded)
        
        #expect(output.address == decoded.address)
        #expect(output.amount == decoded.amount)
        #expect(output.datumHash == decoded.datumHash)
    }
    
    @Test
    func testTransactionOutputPostAlonzo() throws {
        let address = try Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
        let amount = Value(coin: 1000000)
        
        let output = TransactionOutputPostAlonzo(
            address: address,
            amount: amount,
            datumOption: DatumOption(
                datum: .datumHash(DatumHash(
                    payload: Data(repeating: 0x01, count: 32))
                )
            ),
            scriptRef: try ScriptRef(
                script: Script(
                    script: .plutusV3Script(PlutusV3Script(
                        data: Data(repeating: 0x02, count: 10))
                    )
                )
            )
        )
        
        let encoded = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(TransactionOutputPostAlonzo.self, from: encoded)
        
        #expect(output.address == decoded.address)
        #expect(output.amount == decoded.amount)
        #expect(output.datumOption == decoded.datumOption)
        #expect(output.scriptRef == decoded.scriptRef)
    }
} 
