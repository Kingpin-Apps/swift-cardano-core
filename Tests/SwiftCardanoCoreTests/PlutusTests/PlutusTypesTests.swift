import Foundation
import Testing
import OrderedCollections
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite("Datum Tests")
struct DatumTests {
    @Test("Test Datum with Unit")
    func testDatumUnit() async throws {
        let unit = SwiftCardanoCore.Unit()
        let datum: Datum = .plutusData(try unit.toPlutusData())
        
        let encoder = CBOREncoder()
        
        let encoded = try encoder.encode([datum])
        
        let hex = encoded.hexEncodedString()
        
        #expect(hex == "81d87980")
    }
}

@Suite("PlutusScript JSON Tests")
struct PlutusScriptJSONTests {
    
    @Test("PlutusV1Script toJSON and fromJSON")
    func testPlutusV1ScriptJSON() async throws {
        let testData = Data("test script data".utf8)
        let script = PlutusV1Script(data: testData)
        
        // Test toJSON
        let json = try script.toJSON()
        #expect(json != nil)
        
        // Verify JSON contains expected fields
        guard let jsonData = json?.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Issue.record("Failed to parse JSON")
            return
        }
        
        #expect(jsonObject["type"] as? String == "PlutusV1Script")
        #expect(jsonObject["version"] as? Int == 1)
        #expect(jsonObject["data"] != nil)
        
        // Test roundtrip
        let decoded = try PlutusV1Script.fromJSON(json!)
        #expect(decoded.data == testData)
        #expect(decoded.version == 1)
    }
    
    @Test("PlutusV2Script toJSON and fromJSON")
    func testPlutusV2ScriptJSON() async throws {
        let testData = Data("test plutus v2 script".utf8)
        let script = PlutusV2Script(data: testData)
        
        // Test toJSON
        let json = try script.toJSON()
        #expect(json != nil)
        
        // Verify JSON contains expected fields
        guard let jsonData = json?.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Issue.record("Failed to parse JSON")
            return
        }
        
        #expect(jsonObject["type"] as? String == "PlutusV2Script")
        #expect(jsonObject["version"] as? Int == 2)
        #expect(jsonObject["data"] != nil)
        
        // Test roundtrip
        let decoded = try PlutusV2Script.fromJSON(json!)
        #expect(decoded.data == testData)
        #expect(decoded.version == 2)
    }
    
    @Test("PlutusV3Script toJSON and fromJSON")
    func testPlutusV3ScriptJSON() async throws {
        let testData = Data("test plutus v3 script".utf8)
        let script = PlutusV3Script(data: testData)
        
        // Test toJSON
        let json = try script.toJSON()
        #expect(json != nil)
        
        // Verify JSON contains expected fields
        guard let jsonData = json?.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Issue.record("Failed to parse JSON")
            return
        }
        
        #expect(jsonObject["type"] as? String == "PlutusV3Script")
        #expect(jsonObject["version"] as? Int == 3)
        #expect(jsonObject["data"] != nil)
        
        // Test roundtrip
        let decoded = try PlutusV3Script.fromJSON(json!)
        #expect(decoded.data == testData)
        #expect(decoded.version == 3)
    }
    
    @Test("PlutusScript enum toJSON and fromJSON")
    func testPlutusScriptEnumJSON() async throws {
        let testData = Data("test script".utf8)
        let script: PlutusScript = .plutusV2Script(PlutusV2Script(data: testData))
        
        // Test toJSON
        let json = try script.toJSON()
        #expect(json != nil)
        
        // Verify JSON contains expected fields
        guard let jsonData = json?.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Issue.record("Failed to parse JSON")
            return
        }
        
        #expect(jsonObject["type"] as? String == "PlutusV2Script")
        #expect(jsonObject["version"] as? Int == 2)
        
        // Test roundtrip
        let decoded = try PlutusScript.fromJSON(json!)
        if case .plutusV2Script(let decodedScript) = decoded {
            #expect(decodedScript.data == testData)
        } else {
            Issue.record("Expected PlutusV2Script")
        }
    }
    
    @Test("PlutusScript debugDescription doesn't crash")
    func testPlutusScriptDebugDescription() async throws {
        let testData = Data("debug test".utf8)
        let script = PlutusV1Script(data: testData)
        
        // This should not crash - the main fix we're testing
        let description = script.debugDescription
        #expect(!description.isEmpty)
        #expect(description.contains("PlutusV1Script"))
    }
    
    @Test("ScriptType with PlutusScript JSON serialization")
    func testScriptTypeJSON() async throws {
        let testData = Data("script type test".utf8)
        let scriptType: ScriptType = .plutusV1Script(PlutusV1Script(data: testData))
        
        // Test toJSON
        let json = try scriptType.toJSON()
        #expect(json != nil)
        
        // Verify JSON is valid
        guard let jsonData = json?.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Issue.record("Failed to parse JSON")
            return
        }
        
        #expect(jsonObject["type"] as? String == "PlutusV1Script")
        
        // Test roundtrip
        let decoded = try ScriptType.fromJSON(json!)
        if case .plutusV1Script(let decodedScript) = decoded {
            #expect(decodedScript.data == testData)
        } else {
            Issue.record("Expected PlutusV1Script")
        }
    }
}
