import Foundation
import PotentCBOR
import PotentCodables
import CryptoKit

typealias TransactionMetadatumLabel = UInt64

// Define an enum for TransactionMetadatum
enum TransactionMetadatum: Codable, Hashable {
    case map([TransactionMetadatum: TransactionMetadatum])
    case list([TransactionMetadatum])
    case int(Int)
    case bytes(Data)
    case text(String)
}

// MARK: - MetadataType
public enum MetadataType: Codable, Hashable, Equatable {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
}

// MARK: - Metadata
public struct Metadata: Codable, Hashable, Equatable {
    typealias KEY_TYPE = TransactionMetadatumLabel
    typealias VALUE_TYPE = TransactionMetadatum
    
    static let MAX_ITEM_SIZE = 64
    
    var data: [KEY_TYPE: VALUE_TYPE] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    private var _data: [KEY_TYPE: VALUE_TYPE] = [:]
    
    subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }

    init(_ data: [KEY_TYPE: VALUE_TYPE]) throws {
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
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
public struct ShelleyMaryMetadata: Codable, Hashable, Equatable {
    var metadata: Metadata
    var nativeScripts: [NativeScripts]?
    
    init(metadata: Metadata, nativeScripts: [NativeScripts]?) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(Metadata.self)
        nativeScripts = try container.decodeIfPresent([NativeScripts].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(metadata)
        try container.encode(nativeScripts)
    }
}

// MARK: - AlonzoMetadata
public struct AlonzoMetadata: Codable, Hashable, Equatable {
    static let TAG: UInt64 = 259
    
    var metadata: Metadata?
    var nativeScripts: [NativeScripts]?
    var plutusV1Script: [PlutusV1Script]?
    var plutusV2Script: [PlutusV2Script]?
    var plutusV3Script: [PlutusV3Script]?
    
    enum CodingKeys: Int, CodingKey {
        case metadata = 0
        case nativeScripts = 1
        case plutusV1Script = 2
        case plutusV2Script = 3
        case plutusV3Script = 4
    }
    
    init(metadata: Metadata?,
         nativeScripts: [NativeScripts]?,
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
            nativeScripts = try CBORDecoder().decode([NativeScripts].self, from: nativeScriptsArray)
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

    public func encode(to encoder: Encoder) throws {
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
}

// MARK: - AuxiliaryData
public struct AuxiliaryData: Codable {
    var data: MetadataType
    
    public init(data: MetadataType) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode(MetadataType.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
        
    public func hash() -> Data {
        let cborData = try! CBOREncoder().encode(data)
        return Data(SHA256.hash(data: cborData))
    }
}
