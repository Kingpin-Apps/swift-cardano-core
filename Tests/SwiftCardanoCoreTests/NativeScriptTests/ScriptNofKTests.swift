import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ScriptNofKTests {
    
    let required = 2
    let scriptPubkey = ScriptPubkey(keyHash:  try! stakeVerificationKey!.hash())

    @Test("Test ScriptNofK Initialization")
    func testInitialization() async throws {
        let script = ScriptNofK(
            required: required,
            scripts: [.scriptPubkey(scriptPubkey)]
        )
        let expectedScript = atLeastNativescript!
        
        #expect(script.scripts == [.scriptPubkey(scriptPubkey)])
        #expect(expectedScript == script)
        
        #expect(ScriptNofK.TYPE == NativeScriptType.scriptNofK)
    }

    @Test("Test ScriptNofK CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = ScriptNofK(
            required: required,
            scripts: [.scriptPubkey(scriptPubkey)]
        )
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(ScriptNofK.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test ScriptNofK JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = ScriptNofK(
            required: required,
            scripts: [.scriptPubkey(scriptPubkey)]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(ScriptNofK.self, from: encodedJSON)
        #expect(decodedScript == script)
    }

    @Test("Test ScriptNofK Hashing")
    func testScriptNofKHashing() async throws {
        let computedHash = try ScriptNofK(
            required: required,
            scripts: [.scriptPubkey(scriptPubkey)]
        ).hash()
        let expectedHash = try atLeastNativescript!.hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("atLeast.json")
        try? FileManager.default.removeItem(at: tempFileURL)
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = ScriptNofK(
            required: required,
            scripts: [.scriptPubkey(scriptPubkey)]
        )
        
        try script.save(to: tempFileURL.path)
        let loadedScript = try ScriptNofK.load(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
