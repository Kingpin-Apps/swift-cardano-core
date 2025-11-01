import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct AfterScriptTests {
    
    let slot = 1000

    @Test("Test AfterScript Initialization")
    func testInitialization() async throws {
        let script = AfterScript(slot: slot)
        let expectedScript = afterNativescript!
        
        #expect(expectedScript.slot == script.slot)
        
        #expect(AfterScript.TYPE == NativeScriptType.invalidHereAfter)
    }

    @Test("Test AfterScript CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = AfterScript(slot: slot)
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(AfterScript.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test AfterScript JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = AfterScript(slot: slot)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(AfterScript.self, from: encodedJSON)
        #expect(decodedScript == script)
    }

    @Test("Test ScriptPAfterScriptubkey Hashing")
    func testScriptPubkeyHashing() async throws {
        let computedHash = try AfterScript(slot: slot).hash()
        let expectedHash = try afterNativescript!.hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("after.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = AfterScript(slot: slot)
        
        try script.saveJSON(to: tempFileURL.path)
        let loadedScript = try AfterScript.loadJSON(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
