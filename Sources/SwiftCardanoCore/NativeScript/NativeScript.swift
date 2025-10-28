import Foundation
import SwiftNcal
import PotentCBOR
import OrderedCollections


// MARK: - MetadataType
public enum NativeScript: Serializable {
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
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, let head = elements.first else {
            throw CardanoCoreError.decodingError("NativeScript expected CBOR array primitive: \(primitive)")
        }
        
        guard case let .uint(type) = head else {
            throw CardanoCoreError.decodingError("NativeScript: expected first element to be unsigned int: \(head)")
        }
        
        switch type {
            case UInt(ScriptPubkey.TYPE.rawValue):
                self = .scriptPubkey(try ScriptPubkey(from: primitive))
            case UInt(ScriptAll.TYPE.rawValue):
                self = .scriptAll(try ScriptAll(from: primitive))
            case UInt(ScriptAny.TYPE.rawValue):
                self = .scriptAny(try ScriptAny(from: primitive))
            case UInt(ScriptNofK.TYPE.rawValue):
                self = .scriptNofK(try ScriptNofK(from: primitive))
            case UInt(BeforeScript.TYPE.rawValue):
                self = .invalidBefore(try BeforeScript(from: primitive))
            case UInt(AfterScript.TYPE.rawValue):
                self = .invalidHereAfter(try AfterScript(from: primitive))
            default:
                throw CardanoCoreError.decodingError("NativeScript: unknown script type \(type)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .scriptPubkey(let script):
                return try script.toPrimitive()
            case .scriptAll(let script):
                return try script.toPrimitive()
            case .scriptAny(let script):
                return try script.toPrimitive()
            case .scriptNofK(let script):
                return try script.toPrimitive()
            case .invalidBefore(let script):
                return try script.toPrimitive()
            case .invalidHereAfter(let script):
                return try script.toPrimitive()
        }
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> NativeScript {
        guard case let .orderedDict(dictValue) = dict,
              case let .string(type) = dictValue[.string("type")] else {
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
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        switch self {
            case .scriptPubkey(let script):
                guard case let .orderedDict(scriptDict) = try script.toDict() else {
                    throw CardanoCoreError.decodingError("Expected orderedDict from script.toDict()")
                }
                dict[.string("type")] = .string("sig")
                dict.merge(scriptDict, uniquingKeysWith: { lhs, _ in lhs })
            case .scriptAll(_):
                dict[.string("type")] = .string("all")
            case .scriptAny(_):
                dict[.string("type")] = .string("any")
            case .scriptNofK(_):
                dict[.string("type")] = .string("atLeast")
            case .invalidBefore(_):
                dict[.string("type")] = .string("before")
            case .invalidHereAfter(_):
                dict[.string("type")] = .string("after")
        }
        return .orderedDict(dict)
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
public protocol NativeScriptable: Serializable, Sendable {
    static var TYPE: NativeScriptType { get }
}

// Extend the protocol for JSON encoding
public extension NativeScriptable {    
    func hash() throws -> ScriptHash {
        let cbor = try self.toCBORData()
        let hash = try Hash().blake2b(
            data: Data([0x00]) + cbor,
            digestSize: SCRIPT_HASH_SIZE,
            encoder: RawEncoder.self
        )
        return ScriptHash(
            payload: hash
        )
    }
}
