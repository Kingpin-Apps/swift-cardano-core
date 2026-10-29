import CBORCodable
import Foundation
import Testing
@testable import SwiftCardanoCore

/// Metadata and native scripts of any depth the ledger accepts, on their own:
/// read, written, compared, hashed, described and freed on a cooperative
/// thread's 512 KB stack, with the conversions to JSON bounded.
@Suite struct MetadataAndScriptDepthTests {
    static func hex(_ string: String) -> Data { Data(hexString: string)! }
    static func lists(_ n: Int) -> String { String(repeating: "81", count: n) + "00" }
    static func maps(_ n: Int) -> String { String(repeating: "a100", count: n) + "00" }
    static func scripts(_ n: Int) -> String {
        String(repeating: "820181", count: n) + "8200581c" + String(repeating: "44", count: 28)
    }

    @Test(arguments: [lists(16_000), maps(8_000)])
    func deepMetadatum(_ hex: String) async throws {
        let bytes = Self.hex(hex)
        try await Task.detached {
            let value = try MetadatumReader.read(bytes)
            #expect(try MetadatumWriter.encode(value) == bytes)
            #expect(value == (try MetadatumReader.read(bytes)))
            var hasher = Hasher()
            hasher.combine(value)
            _ = value.description
            #expect(try TransactionMetadatum(from: value.toPrimitive()) == value)
            #expect(throws: CardanoCoreError.self) { try value.toDict() }
            // Inside auxiliary data, which keeps its bytes.
            let auxiliary = Self.hex("a1 01".replacingOccurrences(of: " ", with: "")) + bytes
            let decoded = try AuxiliaryData.fromCBOR(data: auxiliary)
            #expect(try decoded.toCBORData() == auxiliary)
        }.value
    }

    @Test func shallowMetadatumConvertsAsBefore() throws {
        let value = try MetadatumReader.read(Self.hex(Self.lists(TransactionMetadatum.maxConversionDepth - 1)))
        guard case .list = try value.toPrimitive() else {
            Issue.record("a shallow metadatum converts to a primitive tree")
            return
        }
        _ = try value.toDict()
        #expect(try MetadatumWriter.encode(value) == CBOREncoder().encode(value.toPrimitive()))
    }

    @Test func deepNativeScript() async throws {
        let bytes = Self.hex(Self.scripts(5_383))
        try await Task.detached {
            let script = try NativeScript.fromCBOR(data: bytes)
            #expect(try script.toCBORData() == bytes)
            #expect(script == (try NativeScript.fromCBOR(data: bytes)))
            var hasher = Hasher()
            hasher.combine(script)
            _ = script.description
            #expect(try NativeScript(from: script.toPrimitive()) == script)
            #expect(throws: CardanoCoreError.self) { try script.toDict() }
            guard case .scriptAll(let all) = script else {
                Issue.record("expected ScriptAll")
                return
            }
            #expect(all.scripts.count == 1)
            #expect(try all.toCBORData() == bytes)
        }.value
    }

    @Test func shallowScriptsMatchTheirPrimitiveEncoding() throws {
        let keyHash = String(repeating: "44", count: 28)
        // atLeast 1 of [any [sig], all [after 5, before 9]]
        let bytes = Self.hex("8303" + "01" + "82" + "820281" + "8200581c" + keyHash
            + "820182" + "820405" + "820509")
        let script = try NativeScript.fromCBOR(data: bytes)
        #expect(try NativeScriptWriter.encode(script) == bytes)
        #expect(try CBOREncoder().encode(script.primitive()) == bytes)
        #expect(try NativeScriptReader.read(bytes) == script)
        #expect(script.description == "atLeast(1, [any([sig(\(keyHash))]), all([after(5), before(9)])])")
    }

    @Test func malformedDeepScriptsAreRejected() {
        // Wrong length, unknown type, a list that is not one, trailing bytes.
        for hex in ["8301" + Self.scripts(1), "820681" + Self.scripts(1), "820100", Self.scripts(3) + "00"] {
            #expect(throws: (any Error).self) { try NativeScriptReader.read(Self.hex(hex)) }
        }
    }
}
