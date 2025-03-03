import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("BabbageTransactionOutput Tests")
struct BabbageTransactionOutputTests {
    
    @Test("Test initialization")
    func testInitialization() async throws {
        let address: Address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
        let amount = Value(coin: 1000000)
        let datum = DatumOption(
            datum: DatumHash(payload: Data(repeating: 1, count: 32))
        )
        let scriptRef = try ScriptRef(
            script: Script(
                script: .nativeScript(.invalidBefore(BeforeScript(slot: 100)))
            )
        )
        
        let output = BabbageTransactionOutput(
            address: address,
            amount: amount,
            datum: datum,
            scriptRef: scriptRef
        )
        
        #expect(output.address == address)
        #expect(output.amount == amount)
        #expect(output.scriptRef?.script.script == scriptRef.script.script)
    }
    
    @Test("Test Codable")
    func testCodable() async throws {
        let address: Address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
        let amount = Value(coin: 1000000)
        let datum = DatumOption(
            datum: DatumHash(payload: Data(repeating: 1, count: 32))
        )
        let scriptRef = try ScriptRef(
            script: Script(
                script: .nativeScript(.invalidBefore(BeforeScript(slot: 100)))
            )
        )
        
        let output = BabbageTransactionOutput(
            address: address,
            amount: amount,
            datum: datum,
            scriptRef: scriptRef
        )
        
        let data = try CBOREncoder().encode(output)
        let decodedOutput = try CBORDecoder().decode(BabbageTransactionOutput.self, from: data)
        
        #expect(decodedOutput.address == output.address)
        #expect(decodedOutput.amount == output.amount)
        #expect(decodedOutput.scriptRef?.script.script == output.scriptRef?.script.script)
    }
    
    @Test("Test optional properties")
    func testOptionalProperties() async throws {
        let address: Address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
        let amount = Value(coin: 1000000)
        
        // Create output without optional properties
        let output = BabbageTransactionOutput(
            address: address,
            amount: amount,
            datum: nil,
            scriptRef: nil
        )
        
        #expect(output.datum == nil)
        #expect(output.scriptRef == nil)
        #expect(output.script == nil)
    }
    
    @Test("Test script property")
    func testScriptProperty() async throws {
        let address: Address = try! Address(from: "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
        let amount = Value(coin: 1000000)
        let nativeScript = NativeScripts.invalidBefore(BeforeScript(slot: 100))
        let scriptRef = try ScriptRef(
            script: Script(script: .nativeScript(nativeScript))
        )
        
        let output = BabbageTransactionOutput(
            address: address,
            amount: amount,
            datum: nil,
            scriptRef: scriptRef
        )
        
        #expect(output.script == .nativeScript(nativeScript))
    }
} 
