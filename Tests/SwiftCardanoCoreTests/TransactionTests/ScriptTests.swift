import Foundation
import PotentCBOR
import Testing
@testable import SwiftCardanoCore

@Suite("DatumOption Tests")
struct DatumOptionTests {
    @Test("Test datum hash initialization")
    func testDatumHashInitialization() throws {
        let datumHash = DatumHash(payload: Data(repeating: 0x01, count: 32))
        let datumOption = DatumOption(datum: .datumHash(datumHash))
        
        #expect(datumOption.type == 0)
        #expect(datumOption.datum == .datumHash(datumHash))
    }
    
    @Test("Test inline datum initialization")
    func testInlineDatumInitialization() throws {
        let plutusData = try PlutusData(fields: [])
        let datumOption = DatumOption(datum: .plutusData(plutusData))
        
        #expect(datumOption.type == 1)
        #expect(datumOption.datum == .plutusData(plutusData))
    }
    
    @Test("Test datum hash encoding and decoding")
    func testDatumHashCoding() throws {
        let datumHash = DatumHash(payload: Data(repeating: 0x01, count: 32))
        let datumOption = DatumOption(datum: .datumHash(datumHash))
        
        let encoded = try CBOREncoder().encode(datumOption)
        let decoded = try CBORDecoder().decode(DatumOption.self, from: encoded)
        
        #expect(decoded.type == datumOption.type)
        #expect(decoded.datum == .datumHash(datumHash))
    }
    
    @Test("Test inline datum encoding and decoding")
    func testInlineDatumCoding() throws {
        let plutusData = PlutusData()
        let datumOption = DatumOption(datum: .plutusData(plutusData))
        
        let encoded = try CBOREncoder().encode(datumOption)
        let decoded = try CBORDecoder().decode(DatumOption.self, from: encoded)
        
        #expect(decoded.type == datumOption.type)
//        #expect(decoded.datum == .plutusData(plutusData))
    }
}

@Suite("Script Tests")
struct ScriptTests {
    @Test("Test script type initialization")
    func testScriptInitialization() throws {
        // Test Native Script
        let nativeScript = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        #expect(nativeScript.type == 0)
        
        // Test Plutus V1 Script
        let plutusV1Data = Data([0x01, 0x02, 0x03])
        let plutusV1Script = Script(
            script: .plutusV1Script(PlutusV1Script(data: plutusV1Data))
        )
        #expect(plutusV1Script.type == 1)
        
        // Test Plutus V2 Script
        let plutusV2Data = Data([0x04, 0x05, 0x06])
        let plutusV2Script = Script(script: .plutusV2Script(PlutusV2Script(data: plutusV2Data)))
        #expect(plutusV2Script.type == 2)
        
        // Test Plutus V3 Script
        let plutusV3Data = Data([0x07, 0x08, 0x09])
        let plutusV3Script = Script(script: .plutusV3Script(PlutusV3Script(data: plutusV3Data)))
        #expect(plutusV3Script.type == 3)
    }
    
    @Test("Test script CBOR encoding and decoding")
    func testScriptEncoding() throws {
        // Test Native Script encoding/decoding
        let nativeScript = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        var encoded = try CBOREncoder().encode(nativeScript)
        var decoded = try CBORDecoder().decode(Script.self, from: encoded)
        #expect(decoded.type == nativeScript.type)
        
        // Test Plutus V2 Script encoding/decoding
        let plutusV2Data = Data([0x01, 0x02, 0x03])
        let plutusScript = Script(
            script: .plutusV2Script(PlutusV2Script(data: plutusV2Data))
        )
        encoded = try CBOREncoder().encode(plutusScript)
        decoded = try CBORDecoder().decode(Script.self, from: encoded)
        
        #expect(decoded.type == plutusScript.type)
        if case .plutusV2Script(let decodedData) = decoded.script,
           case .plutusV2Script(let originalData) = plutusScript.script {
            #expect(decodedData == originalData)
        } else {
            Issue.record("Decoded script is not equal to original")
        }
    }
    
    @Test("Test script equality")
    func testScriptEquality() throws {
        let nativeScript1 = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        let nativeScript2 = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        let plutusScript = Script(
            script:
                    .plutusV2Script(
                        PlutusV2Script(data: Data([0x01, 0x02, 0x03]))
                    )
        )
        
        #expect(nativeScript1 == nativeScript2)
        #expect(nativeScript1 != plutusScript)
        
        // Test hash consistency
        #expect(nativeScript1.hashValue == nativeScript2.hashValue)
        #expect(nativeScript1.hashValue != plutusScript.hashValue)
    }
}

@Suite("ScriptRef Tests")
struct ScriptRefTests {
    @Test("Test script reference initialization")
    func testScriptRefInitialization() throws {
        // Test with Native Script
        let nativeScript = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        let scriptRef = try ScriptRef(script: nativeScript)
        
        #expect(scriptRef.tag == 24)
        #expect(scriptRef.script == nativeScript)
    }
    
    @Test("Test script reference encoding and decoding")
    func testScriptRefCoding() throws {
        // Test with Native Script
        let nativeScript = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        let scriptRef = try ScriptRef(script: nativeScript)
        
        let encoded = try CBOREncoder().encode(scriptRef)
        let decoded = try CBORDecoder().decode(ScriptRef.self, from: encoded)
        
        #expect(decoded.tag == scriptRef.tag)
        #expect(decoded.script == scriptRef.script)
    }
    
    @Test("Test script reference equality")
    func testScriptRefEquality() throws {
        let script = Script(
            script: .nativeScript(.invalidBefore(BeforeScript(slot: 0)))
        )
        let ref1 = try ScriptRef(script: script)
        let ref2 = try ScriptRef(script: script)
        let ref3 = try ScriptRef(
            script: Script(
                script: .plutusV2Script(PlutusV2Script(data: Data([0x01])))
            )
        )
        
        #expect(ref1 == ref2)
        #expect(ref1 != ref3)
    }
} 
