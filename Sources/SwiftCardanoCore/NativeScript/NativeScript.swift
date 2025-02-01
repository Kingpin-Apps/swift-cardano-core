import Foundation
import SwiftNcal
import PotentCBOR


// MARK: - MetadataType
enum NativeScripts: Codable, Equatable, Hashable {
    case scriptPubkey(ScriptPubkey)
    case scriptAll(ScriptAll)
    case scriptAny(ScriptAny)
    case scriptNofK(ScriptNofK)
    case invalidBefore(BeforeScript)
    case invalidHereAfter(AfterScript)
    
    func scriptHash() throws -> ScriptHash {
        switch self {
            case .scriptPubkey(let script): return try script.hash()
            case .scriptAll(let script): return try script.hash()
            case .scriptAny(let script): return try script.hash()
            case .scriptNofK(let script): return try script.hash()
            case .invalidBefore(let script): return try script.hash()
            case .invalidHereAfter(let script): return try script.hash()
        }
    }
}

// MARK: - NativeScriptType
enum NativeScriptType: Int {
    case scriptPubkey = 0
    case scriptAll = 1
    case scriptAny = 2
    case scriptNofK = 3
    case invalidBefore = 4
    case invalidHereAfter = 5
    
    func description() -> String {
        switch self {
            case .scriptPubkey: return "sig"
            case .scriptAll: return "all"
            case .scriptAny: return "any"
            case .scriptNofK: return "atLeast"
            case .invalidBefore: return "before"
            case .invalidHereAfter: return "after"
        }
    }
}

// MARK: - NativeScript Protocol
/// The metadata for a native script.
protocol NativeScript: Codable, Hashable, Equatable {
    static var type: NativeScriptType { get }
}

// Extend the protocol for JSON encoding
extension NativeScript {
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func toCBOR() throws -> Data {
        let cborEncoder = CBOREncoder()
        return try cborEncoder.encode(self)
    }
    
    func hash() throws -> ScriptHash {
        let cbor = try! CBOREncoder().encode(self)
        let hash = try Hash().blake2b(
            data: Data([0x01]) + cbor,
            digestSize: SCRIPT_HASH_SIZE,
            encoder: RawEncoder.self
        )
        return ScriptHash(
            payload: hash
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}
