import Foundation
import CryptoSwift
import PotentCBOR
import PotentCodables

public enum DatumType: Codable, Equatable, Hashable {
    case datumHash(DatumHash)
    case plutusData(PlutusData)
}

public struct DatumOption: Codable {
    var type: Int
    var datum: DatumType

    public init(datum: DatumType) {
        self.datum = datum
        switch datum {
            case .datumHash(_):
                self.type = 0
            case .plutusData(_):
                self.type = 1
        }
    }

    public init(datum: DatumHash) {
        self.datum = .datumHash(datum)
        self.type = 0
    }
    
    public init(datum: PlutusData) {
        self.datum = .plutusData(datum)
        self.type = 1
    }

    enum CodingKeys: String, CodingKey {
        case type = "_TYPE"
        case datum
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        type = try container.decode(Int.self)
        datum = try container.decode(DatumType.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(type)
        try container.encode(datum)
    }
}

public struct Script: Codable, Equatable, Hashable {
    var type: Int
    var script: ScriptType

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
                script = .nativeScript(try container.decode(NativeScripts.self))
            case 1:
                script = .plutusV1Script(try container.decode(Data.self))
            case 2:
                script = .plutusV2Script(try container.decode(Data.self))
            case 3:
                script = .plutusV3Script(try container.decode(Data.self))
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
    var tag: UInt64 = 24
    var value: PotentCodables.AnyValue

    public var script: Script
    
    init(tag: UInt64 = 24, value: PotentCodables.AnyValue) throws {
        guard let script = value.unwrapped as? Data else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef value")
        }
        self.value = value
        self.script = try CBORDecoder().decode(Script.self, from: script)
    }

    public init(script: Script) throws {
        self.script = script
        self.value = AnyValue.data(try CBOREncoder().encode(script))
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
            value: AnyValue.data(try CBOREncoder().encode(script))
        )
        
        var container = encoder.singleValueContainer()
        try container.encode(cborTag)
    }
    
    public static func == (lhs: ScriptRef, rhs: ScriptRef) -> Bool {
        return lhs.tag == rhs.tag && lhs.script == rhs.script
    }
}
