import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ScriptAllTests {
    
    let scriptPubkey = ScriptPubkey(keyHash:  try! stakeVerificationKey!.hash())

    @Test("Test ScriptAll Initialization")
    func testInitialization() async throws {
        let script = ScriptAll(scripts: [.scriptPubkey(scriptPubkey)])
        let expectedScript = allNativescript!
        
        #expect(script.scripts == [.scriptPubkey(scriptPubkey)])
        #expect(expectedScript == script)
        
        #expect(ScriptAll.TYPE == NativeScriptType.scriptAll)
    }

    @Test("Test ScriptAll CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = ScriptAll(scripts: [.scriptPubkey(scriptPubkey)])
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(ScriptAll.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test ScriptAll JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = ScriptAll(scripts: [.scriptPubkey(scriptPubkey)])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(ScriptAll.self, from: encodedJSON)
        #expect(decodedScript == script)
    }

    @Test("Test ScriptAll Hashing")
    func testScriptAllHashing() async throws {
        let computedHash = try ScriptAll(scripts: [.scriptPubkey(scriptPubkey)]).hash()
        let expectedHash = try allNativescript!.hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("all.json")
        try? FileManager.default.removeItem(at: tempFileURL)
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = ScriptAll(scripts: [.scriptPubkey(scriptPubkey)])
        
        try script.saveJSON(to: tempFileURL.path)
        let loadedScript = try ScriptAll.loadJSON(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
