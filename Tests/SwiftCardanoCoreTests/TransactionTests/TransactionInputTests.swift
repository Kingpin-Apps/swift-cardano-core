import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("TransactionInput Tests")
struct TransactionInputTests {
    let transactionId = try! TransactionId(
        from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5")
    )
    let index: UInt16 = 1
    
    @Test("Initialize TransactionInput with valid parameters")
    func testInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: index)
        
        #expect(input.transactionId == transactionId)
        #expect(input.index == index)
        #expect(input.description == "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5#1")
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let originalInput = TransactionInput(transactionId: transactionId, index: index)
        
        let cborEncodedData = try CBOREncoder().encode(originalInput)
        let cborDecodedInput = try CBORDecoder().decode(TransactionInput.self, from: cborEncodedData)
        
        let jsonEncodedData = try JSONEncoder().encode(originalInput)
        let jsonDecodedInput = try JSONDecoder().decode(TransactionInput.self, from: jsonEncodedData)
        
        #expect(cborDecodedInput == originalInput)
        #expect(cborDecodedInput.transactionId == originalInput.transactionId)
        #expect(cborDecodedInput.index == originalInput.index)
        
        #expect(jsonDecodedInput == originalInput)
        #expect(jsonDecodedInput.transactionId == originalInput.transactionId)
        #expect(jsonDecodedInput.index == originalInput.index)
    }
    
    @Test("Test Hashable conformance")
    func testHashable() throws {
        let transactionId2 = try TransactionId(
            from: .string("c1b58dd4f2f4ee8656cc7962eefa8552877c4aa23d0699c02b885363d592a961")
        )
        
        let input1 = TransactionInput(transactionId: transactionId, index: index)
        let input2 = TransactionInput(transactionId: transactionId, index: index)
        let input3 = TransactionInput(transactionId: transactionId2, index: 42)
        let input4 = TransactionInput(transactionId: transactionId, index: 42)
        
        #expect(input1 == input2)
        #expect(input1 != input3)
        #expect(input1 != input4)
        
        var set = Set<TransactionInput>()
        set.insert(input1)
        
        #expect(set.contains(input2))
        #expect(!set.contains(input3))
        #expect(!set.contains(input4))
    }
} 
