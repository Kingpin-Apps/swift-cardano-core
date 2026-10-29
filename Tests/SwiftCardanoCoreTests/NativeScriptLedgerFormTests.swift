import CBORCodable
import Foundation
import SwiftNaCl
import Testing
@testable import SwiftCardanoCore

/// Native scripts as the ledger reads them (`Allegra/Scripts.hs`): each
/// record and list of definite or indefinite length (`decodeRecordSum`,
/// `decodeStrictSeq`), any integer width, and the script's hash taken over
/// the bytes it was written as (a memoised `Timelock`).
@Suite struct NativeScriptLedgerFormTests {
    static let keyHash = String(repeating: "44", count: 28)
    static func hex(_ string: String) -> Data {
        Data(hexString: string.replacingOccurrences(of: " ", with: ""))!
    }
    static func scriptHash(_ bytes: Data) throws -> Data {
        try Hash().blake2b(data: Data([0x00]) + bytes, digestSize: 28, encoder: RawEncoder.self)
    }

    /// all [sig, before 9], in its canonical form.
    static let canonical = hex("82 01 82 8200581c\(keyHash) 820509")

    /// The same script, written as the ledger also accepts it.
    static let otherForms: [String] = [
        "9f 01 82 8200581c\(keyHash) 820509 ff",          // indefinite record
        "82 01 9f 8200581c\(keyHash) 820509 ff",          // indefinite list
        "82 1801 82 8200581c\(keyHash) 820509",           // type written wider
        "82 01 82 9f00581c\(keyHash)ff 8205190009",       // indefinite leaf, wide slot
        "82 01 82 8200 5f 4e\(String(repeating: "44", count: 14)) 4e\(String(repeating: "44", count: 14)) ff 820509", // chunked key hash
    ]

    @Test(arguments: otherForms)
    func readsKeepsAndHashesTheBytesWritten(_ form: String) throws {
        let bytes = Self.hex(form)
        let script = try NativeScript.fromCBOR(data: bytes)
        #expect(script == (try NativeScript.fromCBOR(data: Self.canonical)))
        #expect(try script.toCBORData() == bytes)
        #expect(try script.scriptHash().payload == Self.scriptHash(bytes))
        #expect(try script.scriptHash() != NativeScript.fromCBOR(data: Self.canonical).scriptHash())
        guard case .scriptAll(let all) = script else {
            Issue.record("expected ScriptAll")
            return
        }
        #expect(try all.hash().payload == Self.scriptHash(bytes))
    }

    @Test func aScriptBuiltInSwiftHashesItsCanonicalEncoding() throws {
        let built = NativeScript.scriptAll(ScriptAll(scripts: [
            .scriptPubkey(ScriptPubkey(keyHash: VerificationKeyHash(payload: Self.hex(Self.keyHash)))),
            .invalidHereAfter(AfterScript(slot: 9)),
        ]))
        #expect(built.originalCBOR == nil)
        #expect(try built.toCBORData() == Self.canonical)
        #expect(try built.scriptHash().payload == Self.scriptHash(Self.canonical))
    }

    @Test(arguments: [
        "83 01 80 00",                       // a record of the wrong length
        "9f 01 80 00 ff",                    // an indefinite record with excess terms
        "82 06 80",                          // an unknown type
        "82 01 9f 820509",                   // an indefinite list without its break
        "82 01 80 00",                       // trailing bytes
    ])
    func rejectsWhatTheLedgerRejects(_ form: String) {
        #expect(throws: (any Error).self) { try NativeScript.fromCBOR(data: Self.hex(form)) }
    }

    static let input = "00 81 82 5820" + String(repeating: "33", count: 32) + "00"

    @Test(arguments: otherForms)
    func aWitnessScriptKeepsItsBytes(_ form: String) throws {
        let script = Self.hex(form)
        let tx = Self.hex("84 a3 \(Self.input) 01 80 02 00 a1 01 d90102 81 \(form) f5 f6")
        let decoded = try Transaction.fromCBOR(data: tx)
        let witness = try #require(decoded.transactionWitnessSet.nativeScripts?.asList.first)
        #expect(try witness.scriptHash().payload == Self.scriptHash(script))
        #expect(try decoded.toCBORData() == tx)

        // Encoded afresh, the script is written as it was.
        var changed = decoded
        changed.transactionWitnessSet.vkeyWitnesses = nil
        #expect(try changed.transactionWitnessSet.toCBORData().toHex.contains(script.toHex))
    }

    @Test(arguments: otherForms)
    func anAuxiliaryScriptKeepsItsBytes(_ form: String) throws {
        let script = Self.hex(form)
        // Mary's [metadata, [native scripts]] and Alonzo's #6.259({1: [...]})
        for auxiliary in ["82 a0 81 \(form)", "d90103 a1 01 81 \(form)"] {
            let decoded = try AuxiliaryData.fromCBOR(data: Self.hex(auxiliary))
            let scripts: [NativeScript]? = switch decoded.data {
            case .shelleyMaryMetadata(let metadata): metadata.nativeScripts
            case .alonzoMetadata(let metadata): metadata.nativeScripts
            case .metadata: nil
            }
            let first = try #require(scripts?.first)
            #expect(try first.scriptHash().payload == Self.scriptHash(script))
        }
    }

    @Test(arguments: otherForms)
    func aReferenceScriptKeepsItsBytes(_ form: String) throws {
        let script = Self.hex(form)
        let wrapped = Self.hex("82 00 \(form)")
        let reference = try ScriptRef(tag: 24, value: .bytes(wrapped))
        guard case .nativeScript(let native) = reference.script.script else {
            Issue.record("expected a native script")
            return
        }
        #expect(try native.scriptHash().payload == Self.scriptHash(script))
    }
}
