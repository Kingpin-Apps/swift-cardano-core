import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ScriptAnyTests {
    
    let scriptPubkey = ScriptPubkey(keyHash:  try! stakeVerificationKey!.hash())

    @Test("Test ScriptAny Initialization")
    func testInitialization() async throws {
        let script = ScriptAny(scripts: [.scriptPubkey(scriptPubkey)])
        let expectedScript = anyNativescript!
        
        #expect(script.scripts == [.scriptPubkey(scriptPubkey)])
        #expect(expectedScript == script)
        
        #expect(ScriptAny.TYPE == NativeScriptType.scriptAny)
    }

    @Test("Test ScriptAny CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = ScriptAny(scripts: [.scriptPubkey(scriptPubkey)])
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(ScriptAny.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test ScriptAny JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = ScriptAny(scripts: [.scriptPubkey(scriptPubkey)])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(ScriptAny.self, from: encodedJSON)
        #expect(decodedScript == script)
    }

    @Test("Test ScriptAny Hashing")
    func testScriptAnyHashing() async throws {
        let computedHash = try ScriptAny(scripts: [.scriptPubkey(scriptPubkey)]).hash()
        let expectedHash = try anyNativescript!.hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("any.json")
        try? FileManager.default.removeItem(at: tempFileURL)
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = ScriptAny(scripts: [.scriptPubkey(scriptPubkey)])
        
        try script.save(to: tempFileURL.path)
        let loadedScript = try ScriptAny.load(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
