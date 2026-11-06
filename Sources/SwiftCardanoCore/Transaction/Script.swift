import Foundation
import CryptoSwift
import CBORCodable
import OrderedCollections

/// A script with its language tag, as written in a reference script: `[type, script]`.
public struct Script: Codable, Equatable, Hashable, Sendable {
    /// The language tag: 0 for a native script, 1 for Plutus V1, 2 for Plutus V2, 3 for Plutus V3.
    public var type: Int
    /// The script itself.
    public var script: ScriptType
    
    enum CodingKeys: String, CodingKey {
        case type
        case script
    }
    
    /// Creates a script, setting ``type`` from the kind of script.
    ///
    /// - Parameter script: The script.
    public init(script: ScriptType) {
        self.script = script
        switch script {
            case .nativeScript:
                self.type = 0
            case .plutusV1Script:
                self.type = 1
            case .plutusV2Script:
                self.type = 2
            case .plutusV3Script(_):
                self.type = 3
        }
    }
    
    public init(from decoder: Decoder) throws {
        if String(describing: Swift.type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(Int.self, forKey: .type)
            switch type {
                case 0:
                    script = .nativeScript(try container.decode(NativeScript.self, forKey: .script))
                case 1:
                    script =
                        .plutusV1Script(try container.decode(PlutusV1Script.self, forKey: .script))
                case 2:
                    script = .plutusV2Script(try container.decode(PlutusV2Script.self, forKey: .script))
                case 3:
                    script = .plutusV3Script(try container.decode(PlutusV3Script.self, forKey: .script))
                default:
                    throw CardanoCoreError
                        .valueError("Invalid Script type: \(type)")
            }
        }
        else {
            var container = try decoder.unkeyedContainer()
            type = try container.decode(Int.self)
            
            switch type {
                case 0:
                    script = .nativeScript(try container.decode(NativeScript.self))
                case 1:
                    script =
                        .plutusV1Script(try container.decode(PlutusV1Script.self))
                case 2:
                    script = .plutusV2Script(try container.decode(PlutusV2Script.self))
                case 3:
                    script = .plutusV3Script(try container.decode(PlutusV3Script.self))
                default:
                    throw CardanoCoreError
                        .valueError("Invalid Script type: \(type)")
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: Swift.type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            switch script {
                case .nativeScript(let script):
                    try container.encode(script, forKey: .script)
                case .plutusV1Script(let script):
                    try container.encode(script, forKey: .script)
                case .plutusV2Script(let script):
                    try container.encode(script, forKey: .script)
                case .plutusV3Script(let script):
                    try container.encode(script, forKey: .script)
            }
        } else  {
            var container = encoder.unkeyedContainer()
            try container.encode(type)
            switch script {
                case .nativeScript(let script):
                    try container.encode(script)
                case .plutusV1Script(let script):
                    try container.encode(script)
                case .plutusV2Script(let script):
                    try container.encode(script)
                case .plutusV3Script(let script):
                    try container.encode(script)
            }
        }
    }
}

/// An output's reference script: `#6.24(bytes .cbor script)`.
public struct ScriptRef: CBORTaggable, Serializable {
    /// The CBOR tag; always 24.
    public var tag: UInt64 = 24
    /// The tagged value: the CBOR bytes of ``script``, which ``toPrimitive()`` writes.
    public var value: Primitive
    
    /// The decoded script. Setting it does not update ``value``.
    public var script: Script
    
    /// Creates a reference script from its tagged value, decoding the script it holds.
    ///
    /// A native script is read again from its own bytes and keeps them, since its
    /// hash is taken over them.
    /// - Parameters:
    ///   - tag: The CBOR tag; must be 24.
    ///   - value: The script's CBOR, as `.bytes`, or as `.string` whose UTF-8 bytes are decoded.
    /// - Throws: `CardanoCoreError.valueError` when `tag` is not 24 or `value` is neither bytes nor a string; a decoding error when the bytes are not a script.
    public init(tag: UInt64 = 24, value: Primitive) throws {
        // script_ref = #6.24(bytes .cbor script)
        guard tag == 24 else {
            throw CardanoCoreError.valueError("Invalid ScriptRef tag: \(tag)")
        }
        if case let .string(script) = value {
            self.script = try Self.script(from: script.toData)
        } else if case let .bytes(script) = value {
            self.script = try Self.script(from: script)
        } else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef value: \(value)")
        }
        self.value = value
    }
    
    /// The script `[type, script]` in `bytes`; a native script is read again
    /// from its bytes, which it keeps, since its hash is taken over them.
    private static func script(from bytes: Data) throws -> Script {
        var script = try CBORDecoder.ledger().decode(Script.self, from: bytes)
        if case .nativeScript = script.script {
            let scanner = CBORItemScanner(bytes)
            let spans = try scanner.elements(ofArrayAt: 0)
            if spans.count == 2 {
                script.script = .nativeScript(try NativeScriptReader.read(bytes.subdata(in: spans[1])))
            }
        }
        return script
    }

    /// Creates a reference script by encoding `script` as the tagged value.
    ///
    /// - Parameter script: The script to reference.
    /// - Throws: An error when the script cannot be encoded.
    public init(script: Script) throws {
        self.script = script
        self.value = .bytes(try CBOREncoder().encode(script))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBORTag.self)
        
        guard cborData.tag == 24 else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef tag: \(cborData.tag)")
        }
        
        try self.init(value: cborData.value)
    }
    
    public func encode(to encoder: Encoder) throws {
        let cborTag = CBORTag(
            tag: 24,
            value: .bytes(try CBOREncoder().encode(script))
        )
        
        var container = encoder.singleValueContainer()
        try container.encode(cborTag)
    }
    
    public static func == (lhs: ScriptRef, rhs: ScriptRef) -> Bool {
        return lhs.tag == rhs.tag && lhs.script == rhs.script
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(cborTag) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef primitive: expected tagged value")
        }
        try self.init(tag: cborTag.tag, value: cborTag.value)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .cborTag(CBORTag(tag: tag, value: value))
    }
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptRef {
        guard case let .orderedDict(dictValue) = dict,
              let tagPrimitive = dictValue[Primitive.string("tag")],
              tagPrimitive.integerValue != nil else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef JSON: missing tag")
        }
        let tagValue = try tagPrimitive.integer("ScriptRef tag", as: UInt64.self)
        
        guard let valuePrimitive = dictValue[Primitive.string("value")] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef JSON: missing value")
        }
        // The value is the script's CBOR bytes, as hex (or base64, as
        // earlier versions wrote it).
        let valueData = try valuePrimitive.jsonBytes("ScriptRef value")
        
        return try ScriptRef(tag: tagValue, value: .bytes(valueData))
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        dict[Primitive.string("tag")] = Primitive.integer(tag)
        
        // The value's bytes, as hex
        let valueBytes: Data
        if case let .bytes(data) = value {
            valueBytes = data
        } else if case let .string(str) = value {
            valueBytes = str.toData
        } else {
            throw CardanoCoreError.valueError("Invalid ScriptRef value type")
        }
        
        dict[Primitive.string("value")] = Primitive.string(valueBytes.toHex)
        return .orderedDict(dict)
    }
}
