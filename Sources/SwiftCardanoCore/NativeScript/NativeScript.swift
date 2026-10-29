import Foundation
import SwiftNaCl
import CBORCodable
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
    
    /// The bytes this script was decoded from, while they are kept: its
    /// encoding and hash are taken over them, as the ledger takes them.
    public internal(set) var originalCBOR: Data? {
        get {
            switch self {
            case .scriptPubkey(let script): return script.originalCBOR
            case .scriptAll(let script): return script.originalCBOR
            case .scriptAny(let script): return script.originalCBOR
            case .scriptNofK(let script): return script.originalCBOR
            case .invalidBefore(let script): return script.originalCBOR
            case .invalidHereAfter(let script): return script.originalCBOR
            }
        }
        set {
            switch self {
            case .scriptPubkey(var script): script.originalCBOR = newValue; self = .scriptPubkey(script)
            case .scriptAll(var script): script.originalCBOR = newValue; self = .scriptAll(script)
            case .scriptAny(var script): script.originalCBOR = newValue; self = .scriptAny(script)
            case .scriptNofK(var script): script.originalCBOR = newValue; self = .scriptNofK(script)
            case .invalidBefore(var script): script.originalCBOR = newValue; self = .invalidBefore(script)
            case .invalidHereAfter(var script): script.originalCBOR = newValue; self = .invalidHereAfter(script)
            }
        }
    }

    /// Reads a script as the ledger does — its records and lists of definite
    /// or indefinite length — keeping its bytes, over which its hash is taken.
    public static func fromCBOR(data: Data) throws -> NativeScript {
        try NativeScriptReader.read(data)
    }

    public init(from cbor: Data) throws {
        self = try NativeScriptReader.read(cbor)
    }

    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        if case .cborSimpleValue(.encoded(let bytes)) = primitive {
            // Carried as its bytes — as a decoder hands over deep scripts —
            // and read without recursing.
            self = try NativeScriptReader.read(bytes)
            return
        }
        if primitive.containsEncoded {
            // A deep script, cut part-way down by the decoder: read it whole.
            // The bytes it is read from are a re-encoding, not what was written.
            self = try NativeScriptReader.read(primitive.encodedBytes())
            self.originalCBOR = nil
            return
        }
        guard let elements = primitive.arrayElements, let head = elements.first else {
            throw CardanoCoreError.decodingError("NativeScript expected CBOR array primitive: \(primitive)")
        }
        
        guard case let .uint(type) = head else {
            throw CardanoCoreError.decodingError("NativeScript: expected first element to be unsigned int: \(head)")
        }
        
        switch type {
            case UInt64(ScriptPubkey.TYPE.rawValue):
                self = .scriptPubkey(try ScriptPubkey(from: primitive))
            case UInt64(ScriptAll.TYPE.rawValue):
                self = .scriptAll(try ScriptAll(from: primitive))
            case UInt64(ScriptAny.TYPE.rawValue):
                self = .scriptAny(try ScriptAny(from: primitive))
            case UInt64(ScriptNofK.TYPE.rawValue):
                self = .scriptNofK(try ScriptNofK(from: primitive))
            case UInt64(BeforeScript.TYPE.rawValue):
                self = .invalidBefore(try BeforeScript(from: primitive))
            case UInt64(AfterScript.TYPE.rawValue):
                self = .invalidHereAfter(try AfterScript(from: primitive))
            default:
                throw CardanoCoreError.decodingError("NativeScript: unknown script type \(type)")
        }
    }

    /// The script as a primitive tree; one nested deeper than
    /// ``maxConversionDepth`` as its encoded bytes, which hold the same script.
    public func toPrimitive() throws -> Primitive {
        if let originalCBOR { return .cborSimpleValue(.encoded(originalCBOR)) }
        if nests(deeperThan: Self.maxConversionDepth) {
            return .cborSimpleValue(.encoded(try NativeScriptWriter.encode(self)))
        }
        return try primitive()
    }

    func primitive() throws -> Primitive {
        if let originalCBOR { return .cborSimpleValue(.encoded(originalCBOR)) }
        switch self {
            case .scriptPubkey(let script):
                return try script.toPrimitive()
            case .scriptAll(let script):
                return try script.primitive()
            case .scriptAny(let script):
                return try script.primitive()
            case .scriptNofK(let script):
                return try script.primitive()
            case .invalidBefore(let script):
                return try script.toPrimitive()
            case .invalidHereAfter(let script):
                return try script.toPrimitive()
        }
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> NativeScript {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid NativeScript dict format")
        }
        
        guard let typePrimitive = dictValue[.string("type")],
              case let .string(type) = typePrimitive else {
            throw CardanoCoreError.decodingError("Missing or invalid type for NativeScript")
        }
        
        switch type {
            case "sig": return .scriptPubkey(try ScriptPubkey.fromDict(dict))
            case "all": return .scriptAll(try ScriptAll.fromDict(dict))
            case "any": return .scriptAny(try ScriptAny.fromDict(dict))
            case "atLeast": return .scriptNofK(try ScriptNofK.fromDict(dict))
            // cardano-cli simple script JSON: "before" = valid only before the slot
            // (invalid_hereafter, code 5); "after" = valid from the slot (invalid_before, code 4).
            case "before": return .invalidHereAfter(try AfterScript.fromDict(dict))
            case "after": return .invalidBefore(try BeforeScript.fromDict(dict))
            default: throw CardanoCoreError.decodingError("Unknown NativeScript type: \(type)")
        }
    }
    
    /// The script as JSON.
    ///
    /// - Throws: When it nests deeper than ``maxConversionDepth``.
    public func toDict() throws -> Primitive {
        guard !nests(deeperThan: Self.maxConversionDepth) else {
            throw CardanoCoreError.valueError(
                "A native script nests deeper than \(Self.maxConversionDepth) levels, too deep to convert to JSON")
        }
        return try dict()
    }

    func dict() throws -> Primitive {
        switch self {
            case .scriptPubkey(let script):
                return try script.toDict()
            case .scriptAll(let script):
                return try script.dict()
            case .scriptAny(let script):
                return try script.dict()
            case .scriptNofK(let script):
                return try script.dict()
            case .invalidBefore(let script):
                return try script.toDict()
            case .invalidHereAfter(let script):
                return try script.toDict()
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
            case .invalidBefore: return "after"
            case .invalidHereAfter: return "before"
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
