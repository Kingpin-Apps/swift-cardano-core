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
    
    func toJSON() -> String? {
        switch self {
            case .scriptPubkey(let script): return script.toJSON()
            case .scriptAll(let script): return script.toJSON()
            case .scriptAny(let script): return script.toJSON()
            case .scriptNofK(let script): return script.toJSON()
            case .invalidBefore(let script): return script.toJSON()
            case .invalidHereAfter(let script): return script.toJSON()
        }
    }
    
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> NativeScripts {
        guard let type = dict["type"] as? String else {
            throw CardanoCoreError.decodingError("Missing type for NativeScript")
        }
        
        switch type {
            case "sig": return .scriptPubkey(try ScriptPubkey.fromDict(dict))
            case "all": return .scriptAll(try ScriptAll.fromDict(dict))
            case "any": return .scriptAny(try ScriptAny.fromDict(dict))
            case "atLeast": return .scriptNofK(try ScriptNofK.fromDict(dict))
            case "before": return .invalidBefore(try BeforeScript.fromDict(dict))
            case "after": return .invalidHereAfter(try AfterScript.fromDict(dict))
            default: throw CardanoCoreError.decodingError("Unknown NativeScript type: \(type)")
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
protocol NativeScript: JSONSerializable {
    static var TYPE: NativeScriptType { get }
}

// Extend the protocol for JSON encoding
extension NativeScript {
    static func fromJSON(_ json: String) throws -> Self {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
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
