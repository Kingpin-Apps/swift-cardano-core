import Testing
import Foundation
import PotentCBOR
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
        #expect(NativeScriptType.invalidBefore.description() == "before")
        #expect(NativeScriptType.invalidHereAfter.description() == "after")
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
}
