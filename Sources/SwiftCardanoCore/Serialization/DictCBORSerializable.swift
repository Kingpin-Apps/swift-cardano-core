import Foundation
import PotentCBOR

/// A dictionary class where all keys share the same type and all values share the same type.
class DictCBORSerializable: CBORSerializable {
    typealias KEY_TYPE = AnyHashable
    typealias VALUE_TYPE = Any
    
    private var _data: [KEY_TYPE: VALUE_TYPE] = [:]
        
    var data: [KEY_TYPE: VALUE_TYPE] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    
    // Subscript for easier key-value access
    subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }
    
    /// Initializer with default validation
    required init(_ data: [KEY_TYPE: VALUE_TYPE]) throws {
        self.data = data
//        try validate()
    }

//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        <#code#>
//    }

    /// Validate keys and values conform to expected types
//    func validate() throws {
//        for (key, value) in data {
//            if let serializableKey = key as? CBORSerializable {
//                try serializableKey.validate()
//            }
//            try value.validate()
//        }
//    }
    
    /// Sort keys in a map according to CBOR encoding rules
    func toShallowPrimitive() throws -> Any {
        let sortedData = try data.sorted {
            let key1Bytes = try ($0.key as! CBORSerializable).toCBOR()
            let key2Bytes = try ($1.key as! CBORSerializable).toCBOR()
            return key1Bytes.count < key2Bytes.count
        }
        return Dictionary(uniqueKeysWithValues: sortedData)
    }
    
    /// Restore a primitive value to its original class type
    class func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let dict = value as? [KEY_TYPE: Any] else {
            throw CardanoCoreError
                .valueError("Expected dictionary for deserialization.")
        }
        
        var restoredData: [KEY_TYPE: VALUE_TYPE] = [:]
        
        for (key, rawValue) in dict {
            let restoredKey: KEY_TYPE
            let restoredValue: VALUE_TYPE
            
            if let keyType = Self.KEY_TYPE.self as? CBORSerializable.Type {
                restoredKey = try keyType.fromPrimitive(key)
            } else {
                restoredKey = key
            }

            if let valueType = Self.VALUE_TYPE as? CBORSerializable.Type {
                restoredValue = try valueType.fromPrimitive(rawValue)
            } else {
                restoredValue = rawValue
            }
            
            restoredData[restoredKey] = restoredValue
        }
        
        return try Self(restoredData) as! T
    }
}
