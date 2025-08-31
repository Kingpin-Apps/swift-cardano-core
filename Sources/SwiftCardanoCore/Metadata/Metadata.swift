import Foundation
import PotentCBOR
import PotentCodables
import CryptoKit
import SwiftNcal
import OrderedCollections

public typealias TransactionMetadatumLabel = UInt64

// Define an enum for TransactionMetadatum
public enum TransactionMetadatum: CBORSerializable, Hashable, Sendable {
    case map([TransactionMetadatum: TransactionMetadatum])
    case list([TransactionMetadatum])
    case int(Int)
    case bytes(Data)
    case text(String)
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .int(let value):
                if value >= Int.min && value <= Int.max {
                    self = .int(Int(value))
                } else {
                    throw CardanoCoreError.deserializeError("Integer value out of bounds for Int type")
                }
            case .bytes(let data):
                self = .bytes(data)
            case .string(let string):
                self = .text(string)
            case .list(let array):
                let list = try array.map { try TransactionMetadatum(from: $0) }
                self = .list(list)
            case .dict(let dict):
                var map = [TransactionMetadatum: TransactionMetadatum]()
                for (key, value) in dict {
                    let keyMeta = try TransactionMetadatum(from: key)
                    let valueMeta = try TransactionMetadatum(from: value)
                    map[keyMeta] = valueMeta
                }
                self = .map(map)
            default:
                throw CardanoCoreError.deserializeError("Unsupported CBOR type for TransactionMetadatum")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .int(let value):
                return .int(Int(value))
            case .bytes(let data):
                return .bytes(data)
            case .text(let string):
                return .string(string)
            case .list(let array):
                let list = try array.map { try $0.toPrimitive() }
                return .list(list)
            case .map(let dict):
                var map = [Primitive: Primitive]()
                for (key, value) in dict {
                    let keyPrim = try key.toPrimitive()
                    let valuePrim = try value.toPrimitive()
                    map[keyPrim] = valuePrim
                }
                return .dict(map)
        }
    }
}

// MARK: - MetadataType
public enum MetadataType: CBORSerializable, Hashable, Equatable {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
    
    public init(from primitive: Primitive) throws {
        if case let .cborTag(cborTag) = primitive,
           cborTag.tag == AlonzoMetadata.TAG {
            self = .alonzoMetadata(try AlonzoMetadata(from: primitive))
            return
        }
        
        if case .dict(_) = primitive {
            let metadata = try Metadata(from: primitive)
            self = .metadata(metadata)
            return
        }
        
        if case let .list(elements) = primitive, elements.count >= 1 {
            // Properly initialize metadata and nativeScripts variables
            var metadata: Metadata!
            var nativeScripts: [NativeScript]?
            
            if case .dict(_) = elements[0] {
                metadata = try Metadata(from: elements[0])
            } else {
                throw CardanoCoreError.deserializeError("Invalid metadata format in ShelleyMaryMetadata")
            }
            
            if elements.count > 1, case let .list(nativeScriptsPrimitive) = elements[1] {
                nativeScripts = try nativeScriptsPrimitive
                    .map { try NativeScript(from: $0) }
            }
            
            self = .shelleyMaryMetadata(
                ShelleyMaryMetadata(metadata: metadata, nativeScripts: nativeScripts)
            )
            return
        }
        
        throw CardanoCoreError.deserializeError("Invalid MetadataType primitive")
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .metadata(let metadata):
            return try metadata.toPrimitive()
        case .shelleyMaryMetadata(let shelleyMaryMetadata):
            return try shelleyMaryMetadata.toPrimitive()
        case .alonzoMetadata(let alonzoMetadata):
            return try alonzoMetadata.toPrimitive()
        }
    }

}

// MARK: - Metadata
public struct Metadata: CBORSerializable, Hashable, Equatable {
    public typealias KEY_TYPE = TransactionMetadatumLabel
    public typealias VALUE_TYPE = TransactionMetadatum
    
    public static let MAX_ITEM_SIZE = 64
    
    public var data: [KEY_TYPE: VALUE_TYPE] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    private var _data: [KEY_TYPE: VALUE_TYPE] = [:]
    
    public subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }

    public init(_ data: [KEY_TYPE: VALUE_TYPE]) throws {
        try validate()
        
        var metadata = [KEY_TYPE: VALUE_TYPE]()
        for (key, value) in data {
            let key = key
            let value = value
            
            metadata[key] = value
        }
        
        self.data = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([KEY_TYPE: VALUE_TYPE].self)
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    public init(from primitive: Primitive) throws {
        self.data = [:]
        
        guard case let .dict(primitiveDict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Metadata type")
        }
        
        for (key, value) in primitiveDict {
            guard case let .int(keyValue) = key,
                  keyValue >= 0 && keyValue <= UInt64.max else {
                throw CardanoCoreError.deserializeError("Invalid Metadata key type")
            }
            
            let key = KEY_TYPE(keyValue)
            let value = try VALUE_TYPE(from: value)
            
            self.data[key] = value
        }
        
        try validate()
    }

    public func toPrimitive() throws -> Primitive {
        var result = [Primitive: Primitive]()
        for (key, value) in data {
            result[.int(Int(key))] = try value.toPrimitive()
        }
        return .dict(result)
    }

    
    private func validate() throws {
        func validateTypeAndSize(_ value: Any) throws {
            if let data = value as? Data, data.count > Self.MAX_ITEM_SIZE {
                throw CardanoCoreError.invalidArgument("Data size exceeds \(Self.MAX_ITEM_SIZE) bytes.")
            } else if let string = value as? String, string.utf8.count > Self.MAX_ITEM_SIZE {
                throw CardanoCoreError.invalidArgument("String size exceeds \(Self.MAX_ITEM_SIZE) bytes.")
            } else if let list = value as? [Any] {
                for item in list {
                    try validateTypeAndSize(item)
                }
            } else if let dict = value as? [String: Any] {
                for (_, v) in dict {
                    try validateTypeAndSize(v)
                }
            }
        }
        
        for (_, value) in data {
            try validateTypeAndSize(value)
        }
    }
}

// MARK: - ShelleyMaryMetadata
public struct ShelleyMaryMetadata: CBORSerializable, Hashable, Equatable {
    public var metadata: Metadata
    public var nativeScripts: [NativeScript]?
    
    public init(metadata: Metadata, nativeScripts: [NativeScript]?) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(Metadata.self)
        nativeScripts = try container.decodeIfPresent([NativeScript].self)
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(metadata)
        try container.encode(nativeScripts)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count >= 1 else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyMaryMetadata type")
        }
        
        metadata = try Metadata(from: elements[0])
        
        if elements.count > 1, case let .list(nativeScriptsPrimitive) = elements[1] {
            nativeScripts = try nativeScriptsPrimitive
                .map { try NativeScript(from: $0) }
        } else {
            nativeScripts = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var array: [Primitive] = []
        array.append(try metadata.toPrimitive())
        
        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toPrimitive() }
            array.append(.list(scriptsPrimitive))
        }
        
        return .list(array)
    }

}

// MARK: - AlonzoMetadata
public struct AlonzoMetadata: CBORSerializable, Hashable, Equatable {
    public static let TAG: UInt64 = 259
    
    public var metadata: Metadata?
    public var nativeScripts: [NativeScript]?
    public var plutusV1Script: [PlutusV1Script]?
    public var plutusV2Script: [PlutusV2Script]?
    public var plutusV3Script: [PlutusV3Script]?
    
    enum CodingKeys: Int, CodingKey {
        case metadata = 0
        case nativeScripts = 1
        case plutusV1Script = 2
        case plutusV2Script = 3
        case plutusV3Script = 4
    }
    
    public init(metadata: Metadata?,
         nativeScripts: [NativeScript]?,
         plutusV1Script: [PlutusV1Script]?,
         plutusV2Script: [PlutusV2Script]?,
         plutusV3Script: [PlutusV3Script]?
    ) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusV3Script = plutusV3Script
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(Int.self)
        
        guard tag == AlonzoMetadata.TAG else {
            throw CardanoCoreError.deserializeError("Expect CBOR tag: \(AlonzoMetadata.TAG), got: \(tag) instead.")
        }
        
        let cborData = try container.decode([Int:Data].self)
    
        if let metadataDict = cborData[0] {
            let dict = try CBORDecoder().decode(
                [Metadata.KEY_TYPE: Metadata.VALUE_TYPE].self,
                from: metadataDict
            )
            metadata = try Metadata(dict)
        } else {
            metadata = nil
        }
        
        if let nativeScriptsArray = cborData[1] {
            nativeScripts = try CBORDecoder().decode([NativeScript].self, from: nativeScriptsArray)
        } else {
            nativeScripts = nil
        }
        
        if let plutusV1ScriptArray = cborData[2] {
            plutusV1Script = try CBORDecoder().decode([PlutusV1Script].self, from: plutusV1ScriptArray)
        } else {
            plutusV1Script = nil
        }
        
        if let plutusV2ScriptArray = cborData[3] {
            plutusV2Script = try CBORDecoder().decode([PlutusV2Script].self, from: plutusV2ScriptArray)
        } else {
            plutusV2Script = nil
        }
        
        if let plutusV3ScriptArray = cborData[4] {
            plutusV3Script = try CBORDecoder().decode([PlutusV3Script].self, from: plutusV3ScriptArray)
        } else {
            plutusV3Script = nil
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var cbor: [Int:Data] = [:]
        
        if metadata != nil {
            cbor[0] = try CBOREncoder().encode(metadata!.data)
        }
        
        if nativeScripts != nil {
            cbor[1] = try CBOREncoder().encode(nativeScripts!)
        }
        
        if plutusV1Script != nil {
            cbor[2] = try CBOREncoder().encode(plutusV1Script!)
        }
        
        if plutusV2Script != nil {
            cbor[3] = try CBOREncoder().encode(plutusV2Script!)
        }
        
        if plutusV3Script != nil {
            cbor[4] = try CBOREncoder().encode(plutusV3Script!)
        }
        
        var container = encoder.unkeyedContainer()
        try container.encode(AlonzoMetadata.TAG)
        
        try container.encode(cbor)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(cborTag) = primitive,
                cborTag.tag == AlonzoMetadata.TAG,
              case let .dictionary(cborDict) = cborTag.value else {
            throw CardanoCoreError.deserializeError("Invalid AlonzoMetadata type")
        }
        
        if let metadataPrimitive = cborDict[.int(Int(0))] {
            self.metadata = try Metadata(from: metadataPrimitive.toPrimitive())
        } else {
            self.metadata = nil
        }
        
        if let nativeScriptsPrimitive = cborDict[.int(Int(1))],
           case let .array(scriptsList) = nativeScriptsPrimitive {
            self.nativeScripts = try scriptsList.compactMap { primitive -> NativeScript? in
                let primValue = primitive.toPrimitive()
                return try NativeScript(from: primValue)
            }
        } else {
            self.nativeScripts = nil
        }
        
        if let plutusV1ScriptPrimitive = cborDict[.int(Int(2))],
           case let .array(scriptsList) = plutusV1ScriptPrimitive {
            self.plutusV1Script = try scriptsList.compactMap { primitive -> PlutusV1Script? in
                let primValue = primitive.toPrimitive()
                return try PlutusV1Script(from: primValue)
            }
        } else {
            self.plutusV1Script = nil
        }
        
        if let plutusV2ScriptPrimitive = cborDict[.int(Int(3))],
           case let .array(scriptsList) = plutusV2ScriptPrimitive {
            self.plutusV2Script = try scriptsList.compactMap { primitive -> PlutusV2Script? in
                let primValue = primitive.toPrimitive()
                return try PlutusV2Script(from: primValue)
            }
        } else {
            self.plutusV2Script = nil
        }
        
        if let plutusV3ScriptPrimitive = cborDict[.int(Int(4))],
              case let .array(scriptsList) = plutusV3ScriptPrimitive {
            self.plutusV3Script = try scriptsList.compactMap { primitive -> PlutusV3Script? in
                let primValue = primitive.toPrimitive()
                return try PlutusV3Script(from: primValue)
            }
        } else {
            self.plutusV3Script = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var cborDict = [Primitive: Primitive]()
        
        if let metadata = metadata {
            cborDict[.int(0)] = try metadata.toPrimitive()
        }
        
        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toPrimitive() }
            cborDict[.int(1)] = .list(scriptsPrimitive)
        }
        
        if let plutusV1Script = plutusV1Script {
            let scriptsPrimitive = try plutusV1Script.map { try $0.toPrimitive() }
            cborDict[.int(2)] = .list(scriptsPrimitive)
        }
        
        if let plutusV2Script = plutusV2Script {
            let scriptsPrimitive = try plutusV2Script.map { try $0.toPrimitive() }
            cborDict[.int(3)] = .list(scriptsPrimitive)
        }
        
        if let plutusV3Script = plutusV3Script {
            let scriptsPrimitive = try plutusV3Script.map { try $0.toPrimitive() }
            cborDict[.int(4)] = .list(scriptsPrimitive)
        }
        
        return .cborTag(
            CBORTag(
                tag: Self.TAG,
                value: .dictionary(
                    OrderedDictionary(
                        uniqueKeysWithValues:
                            cborDict.map(
                                { ($0.key.toAnyValue(), $0.value.toAnyValue()) }
                            )
                    )
                    
                )
            )
        )
    }

}

// MARK: - AuxiliaryData
public struct AuxiliaryData: CBORSerializable, Equatable, Hashable {
    public init(from primitive: Primitive) throws {
        self.data = try MetadataType(from: primitive)
    }

    public func toPrimitive() throws -> Primitive {
        return try data.toPrimitive()
    }

    public var data: MetadataType
    
    public init(data: MetadataType) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode(MetadataType.self)
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    public func hash() throws -> AuxiliaryDataHash {
        return AuxiliaryDataHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: self.toCBORData(),
                digestSize: AUXILIARY_DATA_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
}
