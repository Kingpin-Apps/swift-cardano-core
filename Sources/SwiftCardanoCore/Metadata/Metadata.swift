import Foundation
import PotentCBOR
import PotentCodables
import SwiftNcal
import OrderedCollections

public typealias TransactionMetadatumLabel = UInt64

// Define an enum for TransactionMetadatum
public enum TransactionMetadatum: Serializable, Hashable, Equatable {
    case map(OrderedDictionary<TransactionMetadatum, TransactionMetadatum>)
    case list([TransactionMetadatum])
    case int(Int)
    case bytes(Data)
    case text(String)
    
    public var debugDescription: String {
        switch self {
            case .int(let i): return "int(\(i))"
            case .bytes(let data): return "bytes(\(data.base64EncodedString()))"
            case .text(let str): return "text(\(str))"
            case .list(let arr): return "list(\(arr.count) items)"
            case .map(let dict): return "map(\(dict.count) items)"
        }
    }
    
    public var description: String {
        return debugDescription
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .uint(let value):
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
                var map = OrderedDictionary<TransactionMetadatum, TransactionMetadatum>()
                for (key, value) in dict {
                    let keyMeta = try TransactionMetadatum(from: key)
                    let valueMeta = try TransactionMetadatum(from: value)
                    map[keyMeta] = valueMeta
                }
                self = .map(map)
            case .orderedDict(let dict):
                var map = OrderedDictionary<TransactionMetadatum, TransactionMetadatum>()
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
                return .uint(UInt(value))
            case .bytes(let data):
                return .bytes(data)
            case .text(let string):
                return .string(string)
            case .list(let array):
                let list = try array.map { try $0.toPrimitive() }
                return .list(list)
            case .map(let dict):
                var map = OrderedDictionary<Primitive, Primitive>()
                for (key, value) in dict {
                    let keyPrim = try key.toPrimitive()
                    let valuePrim = try value.toPrimitive()
                    map[keyPrim] = valuePrim
                }
                return .orderedDict(map)
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> TransactionMetadatum {
        switch primitive {
            case .uint(let value):
                if value >= Int.min && value <= Int.max {
                    return .int(Int(value))
                } else {
                    throw CardanoCoreError.deserializeError("Integer value out of bounds for Int type")
                }
            case .bytes(let data):
                return .bytes(data)
            case .string(let string):
                return .text(string)
            case .list(let array):
                let list = try array.map { try TransactionMetadatum.fromDict($0) }
                return .list(list)
            case .dict(let dict):
                // Convert to OrderedDictionary maintaining deterministic order
                // Sort keys to ensure consistent ordering across serialization/deserialization
                let sortedKeys = dict.keys.sorted { lhs, rhs in
                    // Sort primitives by their string representation for deterministic ordering
                    String(describing: lhs) < String(describing: rhs)
                }
                var map = OrderedDictionary<TransactionMetadatum, TransactionMetadatum>()
                for key in sortedKeys {
                    let keyMeta = try TransactionMetadatum.fromDict(key)
                    let valueMeta = try TransactionMetadatum.fromDict(dict[key]!)
                    map[keyMeta] = valueMeta
                }
                return .map(map)
            case .orderedDict(let dict):
                var map = OrderedDictionary<TransactionMetadatum, TransactionMetadatum>()
                for (key, value) in dict {
                    let keyMeta = try TransactionMetadatum.fromDict(key)
                    let valueMeta = try TransactionMetadatum.fromDict(value)
                    map[keyMeta] = valueMeta
                }
                return .map(map)
            default:
                throw CardanoCoreError.deserializeError("Unsupported CBOR type for TransactionMetadatum")
        }
    }
    
    public func toDict() throws -> Primitive {
        switch self {
            case .int(let value):
                return .int(value)
            case .bytes(let data):
                return .string(data.base64EncodedString())
            case .text(let string):
                return .string(string)
            case .list(let array):
                let list = try array.map { try $0.toDict() }
                return .list(list)
            case .map(let map):
                var orderedDict = OrderedDictionary<Primitive, Primitive>()
                for (key, value) in map {
                    // Convert key to string for JSON compatibility
                    let keyStr: String
                    switch key {
                    case .int(let i):
                        keyStr = String(i)
                    case .bytes(let data):
                        keyStr = data.base64EncodedString()
                    case .text(let str):
                        keyStr = str
                    case .list(_), .map(_):
                        // For complex keys, serialize to JSON string
                        keyStr = try String(describing: key.toDict())
                    }
                    let valuePrim = try value.toDict()
                    orderedDict[.string(keyStr)] = valuePrim
                }
                return .orderedDict(orderedDict)
        }
    }

}

// MARK: - MetadataType
public enum MetadataType: Serializable, Equatable {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
    
    // Custom Equatable to handle semantic comparison
    public static func == (lhs: MetadataType, rhs: MetadataType) -> Bool {
        switch (lhs, rhs) {
        case (.metadata(let lhsData), .metadata(let rhsData)):
            return lhsData == rhsData
        case (.shelleyMaryMetadata(let lhsData), .shelleyMaryMetadata(let rhsData)):
            return lhsData == rhsData
        case (.alonzoMetadata(let lhsData), .alonzoMetadata(let rhsData)):
            return lhsData == rhsData
        // Handle cross-variant comparison: plain Metadata vs AlonzoMetadata with only metadata
        case (.metadata(let plainMetadata), .alonzoMetadata(let alonzoMetadata)):
            // AlonzoMetadata with only metadata field set is semantically equivalent to plain Metadata
            return alonzoMetadata.nativeScripts == nil &&
                   alonzoMetadata.plutusV1Script == nil &&
                   alonzoMetadata.plutusV2Script == nil &&
                   alonzoMetadata.plutusV3Script == nil &&
                   alonzoMetadata.metadata == plainMetadata
        case (.alonzoMetadata(let alonzoMetadata), .metadata(let plainMetadata)):
            // Symmetric case
            return alonzoMetadata.nativeScripts == nil &&
                   alonzoMetadata.plutusV1Script == nil &&
                   alonzoMetadata.plutusV2Script == nil &&
                   alonzoMetadata.plutusV3Script == nil &&
                   alonzoMetadata.metadata == plainMetadata
        default:
            return false
        }
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        if case let .cborTag(cborTag) = primitive,
           cborTag.tag == AlonzoMetadata.TAG {
            self = .alonzoMetadata(try AlonzoMetadata(from: primitive))
            return
        }
        
        if case .orderedDict(_) = primitive {
            let metadata = try Metadata(from: primitive)
            self = .metadata(metadata)
            return
        }
        
        if case let .list(elements) = primitive, elements.count >= 1 {
            // Properly initialize metadata and nativeScripts variables
            var metadata: Metadata!
            var nativeScripts: [NativeScript]?
            
            if case .orderedDict(_) = elements[0] {
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
        
        throw CardanoCoreError.deserializeError("Invalid MetadataType primitive: \(primitive)")
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

    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> MetadataType {
        // Check if it's a wrapped format with type discriminator
        if case let .orderedDict(dict) = primitive,
           let metadataValue = dict[.string("metadata")] {
            // The wrapper just contains plain Metadata, but we need to check if there are other fields
            // that would indicate this is actually AlonzoMetadata
            if dict.count == 1 {
                // Only "metadata" key, so it's plain Metadata
                return .metadata(try Metadata.fromDict(metadataValue))
            } else {
                // Has other fields, could be AlonzoMetadata
                return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
            }
        }
        
        // Try to detect the type based on structure
        // AlonzoMetadata is a dict with numeric keys
        if case let .dict(dict) = primitive,
           dict.keys.contains(where: { if case .uint(_) = $0 { return true }; return false }) {
            return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
        }
        
        if case let .orderedDict(dict) = primitive,
           dict.keys.contains(where: { if case .uint(_) = $0 { return true }; return false }) {
            return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
        }
        
        // ShelleyMaryMetadata is a list with at least 1 element
        if case let .list(elements) = primitive, elements.count >= 1 {
            return .shelleyMaryMetadata(try ShelleyMaryMetadata.fromDict(primitive))
        }
        
        // Otherwise try as plain Metadata (dict)
        if case .dict(_) = primitive {
            return .metadata(try Metadata.fromDict(primitive))
        }
        
        if case .orderedDict(_) = primitive {
            return .metadata(try Metadata.fromDict(primitive))
        }
        
        throw CardanoCoreError.deserializeError("Invalid MetadataType primitive: \(primitive)")
    }
    
    public func toDict() throws -> Primitive {
        switch self {
        case .metadata(let metadata):
            // Wrap with "metadata" key for JSON format
            var wrapper = OrderedDictionary<Primitive, Primitive>()
            wrapper[.string("metadata")] = try metadata.toDict()
            return .orderedDict(wrapper)
        case .shelleyMaryMetadata(let shelleyMaryMetadata):
            return try shelleyMaryMetadata.toDict()
        case .alonzoMetadata(let alonzoMetadata):
            return try alonzoMetadata.toDict()
        }
    }

}

// MARK: - Metadata
public struct Metadata: Serializable, Equatable {
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
    
    // Custom Equatable to handle dictionary comparison regardless of internal ordering
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.data == rhs.data
    }
    
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
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        self.data = [:]
        
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid Metadata type: \(primitive)")
        }
        
        for (key, value) in primitiveDict {
            guard case let .uint(keyValue) = key,
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
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in data {
            dict[.uint(UInt(key))] = try value.toPrimitive()
        }
        return .orderedDict(dict)
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> Metadata {
        var dict: OrderedDictionary<Primitive, Primitive>
        
        switch primitive {
        case let .dict(d):
            dict = OrderedDictionary(uniqueKeysWithValues: d.map { ($0.key, $0.value) })
        case let .orderedDict(d):
            dict = d
        default:
            throw CardanoCoreError.deserializeError("Expected dictionary for Metadata")
        }
        
        var metadata = [KEY_TYPE: VALUE_TYPE]()
        
        for (key, value) in dict {
            let keyValue: UInt64
            switch key {
            case let .string(strValue):
                guard let uint = UInt64(strValue) else {
                    throw CardanoCoreError.deserializeError("Expected numeric string key in Metadata dictionary")
                }
                keyValue = uint
            case let .uint(uintValue):
                keyValue = UInt64(uintValue)
            case let .int(intValue):
                keyValue = UInt64(intValue)
            default:
                throw CardanoCoreError.deserializeError("Expected string or uint key in Metadata dictionary, got: \(key)")
            }
            
            let metadatumValue = try VALUE_TYPE.fromDict(value)
            metadata[KEY_TYPE(keyValue)] = metadatumValue
        }
        
        return try Metadata(metadata)
    }
    
    public func toDict() throws -> Primitive {
        var result = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in data {
            result[.string(String(key))] = try value.toDict()
        }
        return .orderedDict(result)
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
public struct ShelleyMaryMetadata: Serializable, Equatable {
    public var metadata: Metadata
    public var nativeScripts: [NativeScript]?
    
    public init(metadata: Metadata, nativeScripts: [NativeScript]?) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
    }
    
    // MARK: - CBORSerializable
    
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

    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> ShelleyMaryMetadata {
        guard case let .list(elements) = primitive, elements.count >= 1 else {
            throw CardanoCoreError.deserializeError("Expected list with at least 1 element for ShelleyMaryMetadata")
        }
        
        let metadata = try Metadata.fromDict(elements[0])
        
        var nativeScripts: [NativeScript]?
        if elements.count > 1, case let .list(scriptsList) = elements[1] {
            nativeScripts = try scriptsList.map { try NativeScript.fromDict($0) }
        }
        
        return ShelleyMaryMetadata(metadata: metadata, nativeScripts: nativeScripts)
    }
    
    public func toDict() throws -> Primitive {
        var array: [Primitive] = []
        array.append(try metadata.toDict())
        
        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toDict() }
            array.append(.list(scriptsPrimitive))
        }
        
        return .list(array)
    }

}

// MARK: - AlonzoMetadata
public struct AlonzoMetadata: Serializable, Equatable {
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
    
    public init(metadata: Metadata? = nil,
         nativeScripts: [NativeScript]? = nil,
         plutusV1Script: [PlutusV1Script]? = nil,
         plutusV2Script: [PlutusV2Script]? = nil,
         plutusV3Script: [PlutusV3Script]? = nil
    ) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusV3Script = plutusV3Script
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(cborTag) = primitive,
              cborTag.tag == AlonzoMetadata.TAG else {
            throw CardanoCoreError.deserializeError("Invalid AlonzoMetadata: Not CBOR tag \(AlonzoMetadata.TAG)")
        }
        
        // Handle the case where tag value is a dictionary/map structure
        var cborDict: OrderedDictionary<Primitive, Primitive> = OrderedDictionary<Primitive, Primitive>()
        
        switch cborTag.value {
            case .dict(let dict):
                cborDict.merge(dict) { (_, new) in new }
            case .orderedDict(let dict):
                cborDict = dict
            case .indefiniteDictionary(let dict):
                cborDict = dict
            default:
                // For any other value type (including maps converted to dictionaries),
                // we'll create an empty dictionary and proceed with no metadata
                // This handles edge cases where the tag exists but has no structured content
                break
        }
        
        if let metadataPrimitive = cborDict[.uint(0)] {
            self.metadata = try Metadata(from: metadataPrimitive.toPrimitive())
        } else {
            self.metadata = nil
        }
        
        if let nativeScriptsPrimitive = cborDict[.uint(1)],
           case let .list(scriptsList) = nativeScriptsPrimitive {
            self.nativeScripts = try scriptsList.compactMap { primitive -> NativeScript? in
                let primValue = try primitive.toPrimitive()
                return try NativeScript(from: primValue)
            }
        } else {
            self.nativeScripts = nil
        }
        
        if let plutusV1ScriptPrimitive = cborDict[.uint(2)],
           case let .list(scriptsList) = plutusV1ScriptPrimitive {
            self.plutusV1Script = try scriptsList.compactMap { primitive -> PlutusV1Script? in
                let primValue = try primitive.toPrimitive()
                return try PlutusV1Script(from: primValue)
            }
        } else {
            self.plutusV1Script = nil
        }
        
        if let plutusV2ScriptPrimitive = cborDict[.uint(3)],
           case let .list(scriptsList) = plutusV2ScriptPrimitive {
            self.plutusV2Script = try scriptsList.compactMap { primitive -> PlutusV2Script? in
                let primValue = try primitive.toPrimitive()
                return try PlutusV2Script(from: primValue)
            }
        } else {
            self.plutusV2Script = nil
        }
        
        if let plutusV3ScriptPrimitive = cborDict[.uint(4)],
              case let .list(scriptsList) = plutusV3ScriptPrimitive {
            self.plutusV3Script = try scriptsList.compactMap { primitive -> PlutusV3Script? in
                let primValue = try primitive.toPrimitive()
                return try PlutusV3Script(from: primValue)
            }
        } else {
            self.plutusV3Script = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var cborDict = OrderedDictionary<Primitive, Primitive>()
        
        if let metadata = metadata {
            cborDict[.uint(0)] = try metadata.toPrimitive()
        }
        
        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toPrimitive() }
            cborDict[.uint(1)] = .list(scriptsPrimitive)
        }
        
        if let plutusV1Script = plutusV1Script {
            let scriptsPrimitive = try plutusV1Script.map { try $0.toPrimitive() }
            cborDict[.uint(2)] = .list(scriptsPrimitive)
        }
        
        if let plutusV2Script = plutusV2Script {
            let scriptsPrimitive = try plutusV2Script.map { try $0.toPrimitive() }
            cborDict[.uint(3)] = .list(scriptsPrimitive)
        }
        
        if let plutusV3Script = plutusV3Script {
            let scriptsPrimitive = try plutusV3Script.map { try $0.toPrimitive() }
            cborDict[.uint(4)] = .list(scriptsPrimitive)
        }
        
        return .cborTag(
            CBORTag(
                tag: Self.TAG,
                value: .orderedDict(cborDict)
            )
        )
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> AlonzoMetadata {
        var dict: OrderedDictionary<Primitive, Primitive>
        
        switch primitive {
        case let .dict(d):
            dict = OrderedDictionary(uniqueKeysWithValues: d.map { ($0.key, $0.value) })
        case let .orderedDict(d):
            dict = d
        default:
            throw CardanoCoreError.deserializeError("Expected dictionary for AlonzoMetadata")
        }
        
        let metadata: Metadata?
        if let metadataPrimitive = dict[.string("metadata")] {
            metadata = try Metadata.fromDict(metadataPrimitive)
        } else {
            metadata = nil
        }
        
        let nativeScripts: [NativeScript]?
        if let nativeScriptsPrimitive = dict[.string("nativeScripts")],
           case let .list(scriptsList) = nativeScriptsPrimitive {
            nativeScripts = try scriptsList.map { try NativeScript.fromDict($0) }
        } else {
            nativeScripts = nil
        }
        
        let plutusV1Script: [PlutusV1Script]?
        if let plutusV1ScriptPrimitive = dict[.string("plutusV1Script")],
           case let .list(scriptsList) = plutusV1ScriptPrimitive {
            plutusV1Script = try scriptsList.map { try PlutusV1Script.fromDict($0) }
        } else {
            plutusV1Script = nil
        }
        
        let plutusV2Script: [PlutusV2Script]?
        if let plutusV2ScriptPrimitive = dict[.string("plutusV2Script")],
           case let .list(scriptsList) = plutusV2ScriptPrimitive {
            plutusV2Script = try scriptsList.map { try PlutusV2Script.fromDict($0) }
        } else {
            plutusV2Script = nil
        }
        
        let plutusV3Script: [PlutusV3Script]?
        if let plutusV3ScriptPrimitive = dict[.string("plutusV3Script")],
           case let .list(scriptsList) = plutusV3ScriptPrimitive {
            plutusV3Script = try scriptsList.map { try PlutusV3Script.fromDict($0) }
        } else {
            plutusV3Script = nil
        }
        
        return AlonzoMetadata(
            metadata: metadata,
            nativeScripts: nativeScripts,
            plutusV1Script: plutusV1Script,
            plutusV2Script: plutusV2Script,
            plutusV3Script: plutusV3Script
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        
        if let metadata = metadata {
            dict[.string("metadata")] = try metadata.toDict()
        }
        
        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toDict() }
            dict[.string("nativeScripts")] = .list(scriptsPrimitive)
        }
        
        if let plutusV1Script = plutusV1Script {
            let scriptsPrimitive = try plutusV1Script.map { try $0.toDict() }
            dict[.string("plutusV1Script")] = .list(scriptsPrimitive)
        }
        
        if let plutusV2Script = plutusV2Script {
            let scriptsPrimitive = try plutusV2Script.map { try $0.toDict() }
            dict[.string("plutusV2Script")] = .list(scriptsPrimitive)
        }
        
        if let plutusV3Script = plutusV3Script {
            let scriptsPrimitive = try plutusV3Script.map { try $0.toDict() }
            dict[.string("plutusV3Script")] = .list(scriptsPrimitive)
        }
        
        return .orderedDict(dict)
    }

}

// MARK: - AuxiliaryData
public struct AuxiliaryData: Serializable, Equatable {
    public var data: MetadataType
    
    public init(data: MetadataType) {
        self.data = data
    }
    
    // Custom Equatable to handle semantic comparison
    public static func == (lhs: AuxiliaryData, rhs: AuxiliaryData) -> Bool {
        return lhs.data == rhs.data
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
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        self.data = try MetadataType(from: primitive)
    }
    
    public func toPrimitive() throws -> Primitive {
        return try data.toPrimitive()
    }
    
    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> AuxiliaryData {
        let metadataType = try MetadataType.fromDict(primitive)
        return AuxiliaryData(data: metadataType)
    }
    
    public func toDict() throws -> Primitive {
        return try data.toDict()
    }

}
