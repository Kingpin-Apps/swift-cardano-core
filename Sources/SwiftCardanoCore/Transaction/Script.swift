import Foundation
import CryptoSwift
import PotentCBOR
import PotentCodables
import OrderedCollections

public struct Script: Codable, Equatable, Hashable, Sendable {
    public var type: Int
    public var script: ScriptType
    
    enum CodingKeys: String, CodingKey {
        case type
        case script
    }
    
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

public struct ScriptRef: CBORTaggable, Serializable {
    public var tag: UInt64 = 24
    public var value: Primitive
    
    public var script: Script
    
    public init(tag: UInt64 = 24, value: Primitive) throws {
        if case let .string(script) = value {
            self.script = try CBORDecoder().decode(Script.self, from: script.toData)
        } else if case let .bytes(script) = value {
            self.script = try CBORDecoder().decode(Script.self, from: script)
        } else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef value: \(value)")
        }
        self.value = value
    }
    
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
              case let .int(tagValue) = dictValue[Primitive.string("tag")] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef JSON: missing tag")
        }
        
        guard case let .string(valueStr) = dictValue[Primitive.string("value")] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef JSON: missing value")
        }
        
        // The value is base64-encoded CBOR bytes
        guard let valueData = Data(base64Encoded: valueStr) else {
            throw CardanoCoreError.deserializeError("Invalid ScriptRef JSON: invalid base64 value")
        }
        
        return try ScriptRef(tag: UInt64(tagValue), value: .bytes(valueData))
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        dict[Primitive.string("tag")] = Primitive.int(Int(tag))
        
        // Encode value as base64 string
        let valueBytes: Data
        if case let .bytes(data) = value {
            valueBytes = data
        } else if case let .string(str) = value {
            valueBytes = str.toData
        } else {
            throw CardanoCoreError.valueError("Invalid ScriptRef value type")
        }
        
        dict[Primitive.string("value")] = Primitive.string(valueBytes.base64EncodedString())
        return .orderedDict(dict)
    }
}
