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
enum MetadataType: Codable, Hashable, Equatable {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
}

// MARK: - Metadata
struct Metadata: Codable, Hashable, Equatable {
    typealias KEY_TYPE = TransactionMetadatumLabel
    typealias VALUE_TYPE = TransactionMetadatum
    
    static let MAX_ITEM_SIZE = 64
//    let INTERNAL_TYPES: [Any.Type] = [
//        Int.self,
//        String.self,
//        Data.self,
//        Array<Any>.self,
//        Dictionary<String, Any>.self
//    ]
    
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

    init(_ data: [AnyHashable : AnyHashable]) throws {
        try validate()
        guard let data = data as? [KEY_TYPE: VALUE_TYPE] else {
            throw CardanoCoreError.invalidArgument("Invalid metadata data: \(data)")
        }
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([KEY_TYPE: VALUE_TYPE].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    private func validate() throws {
        func validateTypeAndSize(_ value: Any) throws {
//            let type = type(of: value)
//            guard INTERNAL_TYPES.contains(where: { $0 == type }) else {
//                throw CardanoCoreError.invalidArgument("Value \(value) is of unsupported type: \(type)")
//            }
            
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
struct ShelleyMaryMetadata: Codable, Hashable, Equatable {
    var metadata: Metadata
    var nativeScripts: [NativeScripts]?
    
    init(metadata: Metadata, nativeScripts: [NativeScripts]?) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(Metadata.self)
        nativeScripts = try container.decodeIfPresent([NativeScripts].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(metadata)
        try container.encode(nativeScripts)
    }
}

// MARK: - AlonzoMetadata
struct AlonzoMetadata: Codable, Hashable, Equatable {
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
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(Int.self)
        
        guard tag == AlonzoMetadata.TAG else {
            throw CardanoCoreError.deserializeError("Expect CBOR tag: \(AlonzoMetadata.TAG), got: \(tag) instead.")
        }
        
        let cborData = try container.decode(Data.self)
        let cborObject = try CBORSerialization.cbor(from: cborData)
        
        guard let dict = cborObject.unwrapped as? [UInt64: Any] else {
            throw CardanoCoreError.deserializeError("Invalid AlonzoMetadata structure.")
        }
        
        // Step 4: Decode Metadata
        if let metadataDict = dict[0] as? [AnyHashable: AnyHashable] {
            metadata = try Metadata(metadataDict)
        } else {
            metadata = nil
        }
        
        // Step 5: Decode Native Scripts
        if let nativeScriptsArray = dict[1] as? [Any] {
            nativeScripts = try nativeScriptsArray.map {
                guard let scriptData = $0 as? Data else {
                    throw CardanoCoreError.deserializeError("Invalid native script format.")
                }
                return try CBORSerialization.cbor(from: scriptData) as! NativeScripts
            }
        } else {
            nativeScripts = nil
        }
        
        // Step 6: Decode Plutus Scripts
        plutusV1Script = dict[2] as? [PlutusV1Script]
        plutusV2Script = dict[3] as? [PlutusV2Script]
        plutusV3Script = dict[4] as? [PlutusV3Script]
    }

    func encode(to encoder: Encoder) throws {
        let primitive = [
            0: (metadata?.data ?? [:]) as [TransactionMetadatumLabel: TransactionMetadatum],
            1: (nativeScripts ?? []) as [NativeScripts],
            2: (plutusV1Script ?? [Data()]) as [PlutusV1Script],
            3: (plutusV2Script ?? [Data()]) as [PlutusV2Script],
            4: (plutusV3Script ?? [Data()]) as [PlutusV3Script]
        ] as [Int : Any]
        
//        let cborTag = CBORTag(
//            tag: AlonzoMetadata.TAG,
//            value: primitive as AnyValue
//        )
        
        var container = encoder.unkeyedContainer()
        try container.encode(AlonzoMetadata.TAG)
        
//        let cborData = CBOR.tagged(
//            CBOR.Tag(rawValue: AlonzoMetadata.TAG),
//            CBOR.fromAny(primitive)
//        )
//        let serialized = try CBORSerialization.data(from: cborData)
        let cborData = try CBORSerialization.data(from: CBOR.fromAny(primitive))
        
        try container.encode(cborData)
    }
}

// MARK: - AuxiliaryData
struct AuxiliaryData: Codable {
    var data: MetadataType
    
    init(data: MetadataType) {
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode(MetadataType.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
        
    func hash() -> Data {
        let cborData = try! CBOREncoder().encode(data)
        return Data(SHA256.hash(data: cborData))
    }
}
