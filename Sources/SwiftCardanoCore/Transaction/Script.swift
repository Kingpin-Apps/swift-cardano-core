import Foundation
import CryptoSwift
import PotentCBOR
import PotentCodables

public enum DatumType: Codable, Equatable, Hashable {
    case datumHash(DatumHash)
//    case plutusData(PlutusData)
    case anyValue(AnyValue)
    
    public init(from primitive: Primitive) throws {
        if case let .cborTag(cborTag) = primitive {
            // Handle CBOR-encoded data inside the tag
            if case .data(let cborData) = cborTag.value {
                let decodedValue = try CBORDecoder().decode(AnyValue.self, from: cborData)
                self = .anyValue(decodedValue)
            } else {
                self = .anyValue(cborTag.value)
            }
        } else if case .bytes(_) = primitive {
            self = .datumHash(try DatumHash(from: primitive))
        } else {
            throw CardanoCoreError.deserializeError("Invalid DatumType type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .datumHash(let datumHash):
                return datumHash.toPrimitive()
            case .anyValue(let anyValue):
                let data = CBORTag(
                    tag: 24,
                    value: .data(try CBOREncoder().encode(anyValue))
                )
                return .cborTag(data)
        }
    }
}

public struct DatumOption: Codable, Hashable, Equatable {
    public var type: Int
    public var datum: DatumType

    public init(datum: DatumType) {
        self.datum = datum
        switch datum {
            case .datumHash(_):
                self.type = 0
            case .anyValue(_):
                self.type = 1
        }
    }

    public init(datum: DatumHash) {
        self.datum = .datumHash(datum)
        self.type = 0
    }
    
    public init(datum: AnyValue) {
        self.datum = .anyValue(datum)
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid DatumOption type")
        }
        
        if primitive[0] == .int(0) {
            type = 0
            datum = .datumHash(try DatumHash(from: primitive[1]))
        } else if case let .cborTag(cborTag) = primitive[1] {
            type = 1
            // The data is encoded as CBOR inside the tag, so we need to decode it
            if case .data(let cborData) = cborTag.value {
                let decodedValue = try CBORDecoder().decode(AnyValue.self, from: cborData)
                datum = .anyValue(decodedValue)
            } else {
                datum = .anyValue(cborTag.value)
            }
        } else {
            type = 1
            datum = .anyValue(primitive[1].toAnyValue())
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        if self.type == 1 {
            // For inline datum, we need to encode it as tagged CBOR data
            switch datum {
            case .anyValue(let anyValue):
                // Encode the anyValue as CBOR first, then wrap in tag 24
                let datumCBORData = try CBOREncoder().encode(anyValue)
                let cborTag = CBORTag(tag: 24, value: .data(datumCBORData))
                return .list([.int(1), .cborTag(cborTag)])
            case .datumHash(let hash):
                return .list([.int(0), hash.toPrimitive()])
            }
        } else {
            return .list([.int(0), try datum.toPrimitive()])
        }
    }
}

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
    public var value: PotentCodables.AnyValue

    public var script: Script
    
    public init(tag: UInt64 = 24, value: PotentCodables.AnyValue) throws {
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
