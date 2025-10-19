import Foundation
import CryptoSwift
import PotentCBOR
import PotentCodables

public struct Script: Codable, Equatable, Hashable {
    public var type: Int
    public var script: ScriptType

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

    public func encode(to encoder: Encoder) throws {
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

public struct ScriptRef: CBORTaggable {
    public var tag: UInt64 = 24
    public var value: Primitive

    public var script: Script
    
    public init(tag: UInt64 = 24, value: Primitive) throws {
        guard case let .bytes(script) = value else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef value")
        }
        self.value = value
        self.script = try CBORDecoder().decode(Script.self, from: script)
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
}
