import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ScriptPubkeyTests {

    let testKeyHash = try! stakeVerificationKey!.hash()

    @Test("Test ScriptPubkey Initialization")
    func testInitialization() async throws {
        let script = ScriptPubkey(keyHash: testKeyHash)
        
        #expect(script.keyHash == testKeyHash)
        #expect(ScriptPubkey.TYPE == NativeScriptType.scriptPubkey)
    }

    @Test("Test ScriptPubkey CBOR Encoding and Decoding")
    func testCBORSerialization() async throws {
        let script = ScriptPubkey(keyHash: testKeyHash)
        
        let encodedCBOR = try CBOREncoder().encode(script)
        let decodedScript = try CBORDecoder().decode(ScriptPubkey.self, from: encodedCBOR)

        #expect(decodedScript == script)
    }

    @Test("Test ScriptPubkey JSON Encoding and Decoding")
    func testJSONSerialization() async throws {
        let script = ScriptPubkey(keyHash: testKeyHash)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedJSON = try encoder.encode(script)
        let decodedScript = try decoder.decode(ScriptPubkey.self, from: encodedJSON)

        #expect(decodedScript == script)
    }

    @Test("Test ScriptPubkey Hashing")
    func testScriptPubkeyHashing() async throws {
        let computedHash = try ScriptPubkey(keyHash: testKeyHash).hash()
        let expectedHash = try ScriptPubkey(keyHash: testKeyHash).hash()

        #expect(computedHash == expectedHash)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("sig.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let script = ScriptPubkey(keyHash: testKeyHash)
        
        try script.save(to: tempFileURL.path)
        let loadedScript = try ScriptPubkey.load(from: tempFileURL.path)
        #expect(script == loadedScript)
    }
}
