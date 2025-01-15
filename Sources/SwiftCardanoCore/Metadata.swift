import Foundation
import PotentCBOR
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
enum MetadataType: Codable {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
}

// MARK: - Metadata
struct Metadata: Codable {
    typealias KEY_TYPE = TransactionMetadatumLabel
    typealias VALUE_TYPE = TransactionMetadatum
    
    static let MAX_ITEM_SIZE = 64
    let INTERNAL_TYPES: [Any.Type] = [
        Int.self,
        String.self,
        Data.self,
        Array<Any>.self,
        Dictionary<String, Any>.self
    ]
    
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
        self.data = data as! [KEY_TYPE: VALUE_TYPE]
        try validate()
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        data = try container.decode([KEY_TYPE: VALUE_TYPE].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    private func validate() throws {
        func validateTypeAndSize(_ value: Any) throws {
            let type = type(of: value)
            guard INTERNAL_TYPES.contains(where: { $0 == type }) else {
                throw CardanoCoreError.invalidArgument("Value \(value) is of unsupported type: \(type)")
            }
            
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
        
        for (key, value) in data {
            try validateTypeAndSize(value)
        }
    }
}

// MARK: - ShelleyMaryMetadata
struct ShelleyMaryMetadata: Codable {
    var metadata: Metadata
    var nativeScripts: [NativeScript]?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(Metadata.self)
        nativeScripts = try container.decodeIfPresent([NativeScript].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(metadata)
        try container.encode(nativeScripts)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 2 else {
//            throw CardanoCoreError.deserializeError("Invalid ShelleyMaryMetadata data: \(value)")
//        }
//        
//        let metadata = try Metadata(list[0] as! [Int: AnyHashable])
//        let nativeScripts = list[1] as? [NativeScript]
//        
//        return ShelleyMaryMetadata(metadata: metadata, nativeScripts: nativeScripts) as! T
//    }
}

// MARK: - AlonzoMetadata
struct AlonzoMetadata: Codable {
    static let TAG: UInt64 = 259
    
    var metadata: Metadata?
    var nativeScripts: [NativeScript]?
    var plutusScripts: [Data]?
    
    enum CodingKeys: Int, CodingKey {
        case metadata = 0
        case nativeScripts = 1
        case plutusScripts = 2
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
        
        let metadatDict = dict[0] as? [Int: AnyHashable]
        
        metadata = try metadatDict.map { try Metadata($0) }
        nativeScripts = dict[1] as? [NativeScript]
        plutusScripts = dict[2] as? [Data]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(AlonzoMetadata.TAG)
        
        let primitive = [
            0: metadata?.data as Any,
            1: nativeScripts as Any,
            2: plutusScripts as Any
        ] as [Int : Any]
        
        let cborData = CBOR.tagged(
            CBOR.Tag(rawValue: AlonzoMetadata.TAG),
            CBOR.fromAny(primitive)
        )
        let serialized = try CBORSerialization.data(from: cborData)
        
        try container.encode(serialized)
    }
    
//    func toShallowPrimitive() -> Any {
//        let primitive = [
//            0: metadata?.data as Any,
//            1: nativeScripts as Any,
//            2: plutusScripts as Any
//        ] as [Int : Any]
//        
//        return CBOR.tagged(
//            CBOR.Tag(rawValue: AlonzoMetadata.TAG),
//            CBOR.fromAny(primitive)
//        )
//    }
//    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let taggedCBOR = value as? CBOR, case let CBOR.tagged(tag, innerValue) = taggedCBOR else {
//            throw CardanoCoreError.deserializeError("Value does not match the data schema of AlonzoMetadata.")
//        }
//        
//        guard tag.rawValue == TAG else {
//            throw CardanoCoreError.deserializeError("Expect CBOR tag: \(TAG), got: \(tag) instead.")
//        }
//        
//        guard let dict = innerValue.unwrapped as? [UInt64: Any] else {
//            throw CardanoCoreError.deserializeError("Invalid AlonzoMetadata structure.")
//        }
//        
//        let metadata = dict[0] as? [Int: AnyHashable]
//        
//        return AlonzoMetadata(
//            metadata: try metadata.map { try Metadata($0) },
//            nativeScripts: dict[1] as? [NativeScript],
//            plutusScripts: dict[2] as? [Data]
//        ) as! T
//    }
}

// MARK: - AuxiliaryData
struct AuxiliaryData: Codable {
    var data: MetadataType
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        data = try container.decode(MetadataType.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
//    func toShallowPrimitive() throws -> Any {
//        switch data {
//            case .metadata(let metadata):
//                return try metadata.toShallowPrimitive()
//            case .shelleyMaryMetadata(let shelley):
//                return shelley.toShallowPrimitive()
//            case .alonzoMetadata(let alonzo):
//                return alonzo.toShallowPrimitive()
//        }
//    }
//
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let value = value as? MetadataType else {
//            throw CardanoCoreError.deserializeError("Invalid AuxiliaryData data: \(value)")
//        }
//        
//        switch value {
//            case .metadata(let metadata):
//                return try Metadata.fromPrimitive(metadata.data)
//            case .shelleyMaryMetadata(let shelley):
//                return try ShelleyMaryMetadata.fromPrimitive(shelley)
//            case .alonzoMetadata(let alonzo):
//                return try AlonzoMetadata.fromPrimitive(alonzo)
//        }
//    }
        
    func hash() -> Data {
        let cborData = try! CBOREncoder().encode(data)
        return Data(SHA256.hash(data: cborData))
    }
}
