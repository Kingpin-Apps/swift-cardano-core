import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ShelleyTransactionOutput Tests")
struct ShelleyTransactionOutputTests {
    // Test data
    let address = try! Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
    let amount = Value(coin: 1000000)
    let datumHash = DatumHash(payload: Data(repeating: 1, count: DATUM_HASH_SIZE))
    
    @Test("Test initialization with all parameters")
    func testInitializationWithAllParameters() throws {
        let output = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        #expect(output.address == address)
        #expect(output.amount == amount)
        #expect(output.datumHash == datumHash)
    }
    
    @Test("Test initialization without datum hash")
    func testInitializationWithoutDatumHash() throws {
        let output = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: nil
        )
        
        #expect(output.address == address)
        #expect(output.amount == amount)
        #expect(output.datumHash == nil)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let originalOutput = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        let encodedData = try CBOREncoder().encode(originalOutput)
        let decodedOutput = try CBORDecoder().decode(ShelleyTransactionOutput.self, from: encodedData)
        
        #expect(decodedOutput == originalOutput)
        #expect(decodedOutput.address == originalOutput.address)
        #expect(decodedOutput.amount == originalOutput.amount)
        #expect(decodedOutput.datumHash == originalOutput.datumHash)
    }
    
    @Test("Test Codable conformance without datum hash")
    func testCodableWithoutDatumHash() throws {
        let originalOutput = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: nil
        )
        
        let encodedData = try CBOREncoder().encode(originalOutput)
        let decodedOutput = try CBORDecoder().decode(ShelleyTransactionOutput.self, from: encodedData)
        
        #expect(decodedOutput == originalOutput)
        #expect(decodedOutput.address == originalOutput.address)
        #expect(decodedOutput.amount == originalOutput.amount)
        #expect(decodedOutput.datumHash == nil)
    }
    
    @Test("Test Equatable conformance")
    func testEquatable() throws {
        let output1 = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        let output2 = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        let output3 = ShelleyTransactionOutput(
            address: address,
            amount: Value(coin: 2000000),
            datumHash: datumHash
        )
        
        let output4 = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: nil
        )
        
        #expect(output1 == output2)
        #expect(output1 != output3)
        #expect(output1 != output4)
    }
    
    @Test("Test Hashable conformance")
    func testHashable() throws {
        let output1 = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        let output2 = ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
        
        let output3 = ShelleyTransactionOutput(
            address: address,
            amount: Value(coin: 2000000),
            datumHash: datumHash
        )
        
        var set = Set<ShelleyTransactionOutput>()
        set.insert(output1)
        
        #expect(set.contains(output2))
        #expect(!set.contains(output3))
    }
} 
