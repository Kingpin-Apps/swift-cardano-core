import Foundation
import SwiftNcal
import PotentCBOR


// MARK: - MetadataType
public enum NativeScript: CBORSerializable, Equatable, Hashable {
    case scriptPubkey(ScriptPubkey)
    case scriptAll(ScriptAll)
    case scriptAny(ScriptAny)
    case scriptNofK(ScriptNofK)
    case invalidBefore(BeforeScript)
    case invalidHereAfter(AfterScript)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    public func scriptHash() throws -> ScriptHash {
        switch self {
            case .scriptPubkey(let script): return try script.hash()
            case .scriptAll(let script): return try script.hash()
            case .scriptAny(let script): return try script.hash()
            case .scriptNofK(let script): return try script.hash()
            case .invalidBefore(let script): return try script.hash()
            case .invalidHereAfter(let script): return try script.hash()
        }
    }
    
    public init(from decoder: Swift.Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            switch typeString {
                case ScriptPubkey.TYPE.description():
                    self = .scriptPubkey(try ScriptPubkey(from: decoder))
                case ScriptAll.TYPE.description():
                    self = .scriptAll(try ScriptAll(from: decoder))
                case ScriptAny.TYPE.description():
                    self = .scriptAny(try ScriptAny(from: decoder))
                case ScriptNofK.TYPE.description():
                    self = .scriptNofK(try ScriptNofK(from: decoder))
                case BeforeScript.TYPE.description():
                    self = .invalidBefore(try BeforeScript(from: decoder))
                case AfterScript.TYPE.description():
                    self = .invalidHereAfter(try AfterScript(from: decoder))
                default:
                    throw CardanoCoreError.decodingError("Invalid NativeScripts type: \(typeString)")
            }
            
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            switch code {
                case ScriptPubkey.TYPE.rawValue:
                    self = .scriptPubkey(try ScriptPubkey(from: decoder))
                case ScriptAll.TYPE.rawValue:
                    self = .scriptAll(try ScriptAll(from: decoder))
                case ScriptAny.TYPE.rawValue:
                    self = .scriptAny(try ScriptAny(from: decoder))
                case ScriptNofK.TYPE.rawValue:
                    self = .scriptNofK(try ScriptNofK(from: decoder))
                case BeforeScript.TYPE.rawValue:
                    self = .invalidBefore(try BeforeScript(from: decoder))
                case AfterScript.TYPE.rawValue:
                    self = .invalidHereAfter(try AfterScript(from: decoder))
                default:
                    throw CardanoCoreError.decodingError("Invalid NativeScripts type: \(code)")
            }
        }
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
                case .scriptPubkey(let script):
                    try container.encode(ScriptPubkey.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
                case .scriptAll(let script):
                    try container.encode(ScriptAll.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
                case .scriptAny(let script):
                    try container.encode(ScriptAny.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
                case .scriptNofK(let script):
                    try container.encode(ScriptNofK.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
                case .invalidBefore(let script):
                    try container.encode(BeforeScript.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
                case .invalidHereAfter(let script):
                    try container.encode(AfterScript.TYPE.description(), forKey: .type)
                    try script.encode(to: encoder)
            }
        } else {
            switch self {
                case .scriptPubkey(let script):
                    try script.encode(to: encoder)
                case .scriptAll(let script):
                    try script.encode(to: encoder)
                case .scriptAny(let script):
                    try script.encode(to: encoder)
                case .scriptNofK(let script):
                    try script.encode(to: encoder)
                case .invalidBefore(let script):
                    try script.encode(to: encoder)
                case .invalidHereAfter(let script):
                    try script.encode(to: encoder)
            }
        }
    }
    
    public static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> NativeScript {
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
public enum NativeScriptType: Int, Sendable {
    case scriptPubkey = 0
    case scriptAll = 1
    case scriptAny = 2
    case scriptNofK = 3
    case invalidBefore = 4
    case invalidHereAfter = 5
    
    public func description() -> String {
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
public protocol NativeScriptable: JSONSerializable {
    static var TYPE: NativeScriptType { get }
}

// Extend the protocol for JSON encoding
public extension NativeScriptable {
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
}
