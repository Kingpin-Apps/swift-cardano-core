import Foundation
import PotentCBOR

import CryptoKit

// MARK: - MetadataType
enum MetadataType {
    case metadata(Metadata)
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    case alonzoMetadata(AlonzoMetadata)
}

// MARK: - Metadata
class Metadata: DictCBORSerializable {
    typealias KEY_TYPE = Int
    typealias VALUE_TYPE = Any
    
    static let MAX_ITEM_SIZE = 64
    let INTERNAL_TYPES: [Any.Type] = [
        Int.self,
        String.self,
        Data.self,
        Array<Any>.self,
        Dictionary<String, Any>.self
    ]

    required init(_ data: [AnyHashable : Any]) throws {
        try super.init(data as! [Int : Any])
        try validate()
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
            guard key is KEY_TYPE else {
                throw CardanoCoreError.invalidArgument("Key \(key) must be of type \(KEY_TYPE.self)")
            }
            try validateTypeAndSize(value)
        }
    }
}

// MARK: - ShelleyMaryMetadata
struct ShelleyMaryMetadata: ArrayCBORSerializable {
    var metadata: Metadata
    var nativeScripts: [NativeScript]?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyMaryMetadata data: \(value)")
        }
        
        let metadata = try Metadata(list[0] as! [Int: Any])
        let nativeScripts = list[1] as? [NativeScript]
        
        return ShelleyMaryMetadata(metadata: metadata, nativeScripts: nativeScripts) as! T
    }
}

// MARK: - AlonzoMetadata
struct AlonzoMetadata: MapCBORSerializable {
    static let TAG: UInt64 = 259
    
    var metadata: Metadata?
    var nativeScripts: [NativeScript]?
    var plutusScripts: [Data]?
    
    func toShallowPrimitive() -> Any {
        let primitive = [
            0: metadata?.data as Any,
            1: nativeScripts as Any,
            2: plutusScripts as Any
        ] as [Int : Any]
        
        return CBOR.tagged(
            CBOR.Tag(rawValue: AlonzoMetadata.TAG),
            CBOR.fromAny(primitive)
        )
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let taggedCBOR = value as? CBOR, case let CBOR.tagged(tag, innerValue) = taggedCBOR else {
            throw CardanoCoreError.deserializeError("Value does not match the data schema of AlonzoMetadata.")
        }
        
        guard tag.rawValue == TAG else {
            throw CardanoCoreError.deserializeError("Expect CBOR tag: \(TAG), got: \(tag) instead.")
        }
        
        guard let dict = innerValue.unwrapped as? [UInt64: Any] else {
            throw CardanoCoreError.deserializeError("Invalid AlonzoMetadata structure.")
        }
        
        let metadata = dict[0] as? [Int: Any]
        
        return AlonzoMetadata(
            metadata: try metadata.map { try Metadata($0) },
            nativeScripts: dict[1] as? [NativeScript],
            plutusScripts: dict[2] as? [Data]
        ) as! T
    }
}

// MARK: - AuxiliaryData
struct AuxiliaryData: CBORSerializable {
    var data: MetadataType
    
    func toShallowPrimitive() throws -> Any {
        switch data {
            case .metadata(let metadata):
                return try metadata.toShallowPrimitive()
            case .shelleyMaryMetadata(let shelley):
                return shelley.toShallowPrimitive()
            case .alonzoMetadata(let alonzo):
                return alonzo.toShallowPrimitive()
        }
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let value = value as? MetadataType else {
            throw CardanoCoreError.deserializeError("Invalid AuxiliaryData data: \(value)")
        }
        
        switch value {
            case .metadata(let metadata):
                return try Metadata.fromPrimitive(metadata.data)
            case .shelleyMaryMetadata(let shelley):
                return try ShelleyMaryMetadata.fromPrimitive(shelley)
            case .alonzoMetadata(let alonzo):
                return try AlonzoMetadata.fromPrimitive(alonzo)
        }
    }
        
    func hash() -> Data {
        let cborData = try! toCBOR()
        return Data(SHA256.hash(data: cborData))
    }
}
