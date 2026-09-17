import Testing
import Foundation
import CBORCodable
@testable import SwiftCardanoCore

@Suite struct NativeScriptTests {

    let scriptPubkey = ScriptPubkey(
        keyHash: VerificationKeyHash(payload: Data(repeating: 0, count: 28))
    )
    let scriptAll = ScriptAll(scripts: [])
    let scriptAny = ScriptAny(scripts: [])
    let scriptNofK = ScriptNofK(required: 2, scripts: [])
    let beforeScript = BeforeScript(slot: 1000)
    let afterScript = AfterScript(slot: 2000)

    @Test("Test NativeScripts Hashing")
    func testNativeScriptsHashing() async throws {
        let nativeScripts: [(NativeScript, ScriptHash)] = [
            (.scriptPubkey(scriptPubkey), try scriptPubkey.hash()),
            (.scriptAll(scriptAll), try scriptAll.hash()),
            (.scriptAny(scriptAny), try scriptAny.hash()),
            (.scriptNofK(scriptNofK), try scriptNofK.hash()),
            (.invalidBefore(beforeScript), try beforeScript.hash()),
            (.invalidHereAfter(afterScript), try afterScript.hash())
        ]

        for (nativeScript, expectedHash) in nativeScripts {
            let computedHash = try nativeScript.scriptHash()
            #expect(computedHash == expectedHash)
        }
    }

    @Test("Test NativeScriptType Descriptions")
    func testNativeScriptTypeDescriptions() {
        #expect(NativeScriptType.scriptPubkey.description() == "sig")
        #expect(NativeScriptType.scriptAll.description() == "all")
        #expect(NativeScriptType.scriptAny.description() == "any")
        #expect(NativeScriptType.scriptNofK.description() == "atLeast")
        #expect(NativeScriptType.invalidBefore.description() == "after")
        #expect(NativeScriptType.invalidHereAfter.description() == "before")
    }

    @Test("Test NativeScripts CBOR Encoding and Decoding")
    func testNativeScriptsCBORSerialization() async throws {
        let nativeScripts: [NativeScript] = [
            .scriptPubkey(scriptPubkey),
            .scriptAll(scriptAll),
            .scriptAny(scriptAny),
            .scriptNofK(scriptNofK),
            .invalidBefore(beforeScript),
            .invalidHereAfter(afterScript)
        ]

        for nativeScript in nativeScripts {
            let encodedData = try CBOREncoder().encode(nativeScript)
            let decodedScript = try CBORDecoder().decode(NativeScript.self, from: encodedData)

            #expect(decodedScript == nativeScript)
        }
    }

    @Test("Time-lock JSON types match cardano-cli", arguments: [
        ("{\"type\":\"before\",\"slot\":1000}", "f34ce37b50eec3bce2bd096fdaebd447cb92c9e74e2a4093beff8705"),
        ("{\"type\":\"after\",\"slot\":1000}", "592fb0f9d8ed15c06858118d134d5c4b7c77320507810fee9ac2ddf9"),
        ("{\"type\":\"before\",\"slot\":3000}", "e638e31a6c57bde95c0b644ec0c584a239fab33ba99f41c91b410d1d"),
        ("{\"type\":\"after\",\"slot\":2000}", "b2498e090e237579538af4cd5dac343e783c53fd148c9e302ffdc378"),
        ("{\"type\":\"all\",\"scripts\":[{\"type\":\"sig\",\"keyHash\":\"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde\"},{\"type\":\"before\",\"slot\":123456789}]}", "97407954c092fd15026f3bad6ad51f5e764fc24cd7c3ea2073c0ac4e"),
        ("{\"type\":\"all\",\"scripts\":[{\"type\":\"sig\",\"keyHash\":\"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde\"},{\"type\":\"after\",\"slot\":123456789}]}", "029a8f802dd2674a175f104fa7c61820dd7c617d3d540ba42cb9f32e"),
        ("{\"type\":\"any\",\"scripts\":[{\"type\":\"after\",\"slot\":1000},{\"type\":\"sig\",\"keyHash\":\"7629784f5dd93a8e24f982dd2d1f3b8414868d8260edb6a06c847a69\"}]}", "5a5ba42f130741d62384c390cfc84d9ceecc8a4bef38059ff18ba74b"),
    ])
    func testTimeLockJSONMatchesCardanoCLI(json: String, expectedHash: String) throws {
        let script = try NativeScript.fromJSON(json)
        #expect(try script.scriptHash().payload.toHex == expectedHash)

        // Round-trip through JSON keeps the same hash
        let roundTripped = try NativeScript.fromJSON(try #require(try script.toJSON()))
        #expect(try roundTripped.scriptHash() == script.scriptHash())
    }

    @Test("Time-lock JSON maps to the correct ledger constructor")
    func testTimeLockJSONMapping() throws {
        let before = try NativeScript.fromJSON("{\"type\":\"before\",\"slot\":1000}")
        #expect(before == .invalidHereAfter(AfterScript(slot: 1000)))
        #expect(try AfterScript(slot: 1000).toCBORData() == Data([0x82, 0x05, 0x19, 0x03, 0xe8]))

        let after = try NativeScript.fromJSON("{\"type\":\"after\",\"slot\":1000}")
        #expect(after == .invalidBefore(BeforeScript(slot: 1000)))
        #expect(try BeforeScript(slot: 1000).toCBORData() == Data([0x82, 0x04, 0x19, 0x03, 0xe8]))

        #expect(throws: (any Error).self) { try BeforeScript.fromJSON("{\"type\":\"before\",\"slot\":1000}") }
        #expect(throws: (any Error).self) { try AfterScript.fromJSON("{\"type\":\"after\",\"slot\":1000}") }
    }
}
