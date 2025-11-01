import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct BeforeScriptTests {
    
    let slot = 3000

    @Test("Test BeforeScript Initialization")
    func testInitialization() async throws {
        let script = BeforeScript(slot: slot)
        let expectedScript = beforeNativescript!
        
        #expect(expectedScript.slot == script.slot)
        
        #expect(BeforeScript.TYPE == NativeScriptType.invalidBefore)
    }

    @Test("Test BeforeScript CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = BeforeScript(slot: slot)
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(BeforeScript.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test BeforeScript JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = BeforeScript(slot: slot)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(BeforeScript.self, from: encodedJSON)
        #expect(decodedScript == script)
    }

    @Test("Test ScriptPBeforeScriptubkey Hashing")
    func testScriptPubkeyHashing() async throws {
        let computedHash = try BeforeScript(slot: slot).hash()
        let expectedHash = try beforeNativescript!.hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("before.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = BeforeScript(slot: slot)
        
        try script.saveJSON(to: tempFileURL.path)
        let loadedScript = try BeforeScript.loadJSON(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
