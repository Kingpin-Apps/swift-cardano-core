import Foundation
import PotentCBOR

/// A dictionary class where all keys share the same type and all values share the same type.
class DictCBORSerializable: CBORSerializable, Hashable, Comparable {
    typealias KEY_TYPE = AnyHashable
    typealias VALUE_TYPE = AnyHashable
    
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
    
    // Hash function
    func hash(into hasher: inout Hasher) {
        for (key, value) in data {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
    
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
                restoredValue = rawValue as! VALUE_TYPE
            }
            
            restoredData[restoredKey] = restoredValue
        }
        
        return try Self(restoredData) as! T
    }

    static func + (lhs: DictCBORSerializable, rhs: DictCBORSerializable) -> DictCBORSerializable {
        let newAsset = lhs
        for (key, value) in rhs.data {
            if let lhsValue = newAsset.data[key] as? (any AdditiveArithmetic),
               let rhsValue = value as? (any AdditiveArithmetic) {
                if type(of: lhsValue) == type(of: rhsValue) {
                    if let intLhs = lhsValue as? Int, let intRhs = rhsValue as? Int {
                        newAsset.data[key] = (intLhs + intRhs) as VALUE_TYPE
                    } else if let doubleLhs = lhsValue as? Double, let doubleRhs = rhsValue as? Double {
                        newAsset.data[key] = (doubleLhs + doubleRhs) as VALUE_TYPE
                    } else if let floatLhs = lhsValue as? Float, let floatRhs = rhsValue as? Float {
                        newAsset.data[key] = (floatLhs + floatRhs) as VALUE_TYPE
                    } else {
                        fatalError("Unsupported AdditiveArithmetic type")
                    }
                } else {
                    fatalError("Mismatched AdditiveArithmetic types")
                }
            } else {
                fatalError("Values are not of type AdditiveArithmetic")
            }
        }
        return newAsset
    }
    
    static func += (lhs: inout DictCBORSerializable, rhs: DictCBORSerializable) {
        lhs = lhs + rhs
    }

    static func - (lhs: DictCBORSerializable, rhs: DictCBORSerializable) -> DictCBORSerializable {
        let newAsset = lhs
        for (key, value) in rhs.data {
            if let lhsValue = newAsset.data[key] as? (any AdditiveArithmetic),
               let rhsValue = value as? (any AdditiveArithmetic) {
                if type(of: lhsValue) == type(of: rhsValue) {
                    if let intLhs = lhsValue as? Int, let intRhs = rhsValue as? Int {
                        newAsset.data[key] = (intLhs - intRhs) as VALUE_TYPE
                    } else if let doubleLhs = lhsValue as? Double, let doubleRhs = rhsValue as? Double {
                        newAsset.data[key] = (doubleLhs - doubleRhs) as VALUE_TYPE
                    } else if let floatLhs = lhsValue as? Float, let floatRhs = rhsValue as? Float {
                        newAsset.data[key] = (floatLhs - floatRhs) as VALUE_TYPE
                    } else {
                        fatalError("Unsupported AdditiveArithmetic type")
                    }
                } else {
                    fatalError("Mismatched AdditiveArithmetic types")
                }
            } else {
                fatalError("Values are not of type AdditiveArithmetic")
            }
        }
        return newAsset
    }

    static func == (lhs: DictCBORSerializable, rhs: DictCBORSerializable) -> Bool {
        return lhs.data == rhs.data 
    }
    
    static func < (lhs: DictCBORSerializable, rhs: DictCBORSerializable) -> Bool {
        for (key, value) in rhs.data {
            if let lhsValue = lhs.data[key] as? (any AdditiveArithmetic),
               let rhsValue = value as? (any AdditiveArithmetic) {
                if type(of: lhsValue) == type(of: rhsValue) {
                    if let intLhs = lhsValue as? Int, let intRhs = rhsValue as? Int {
                        return intLhs < intRhs
                    } else if let doubleLhs = lhsValue as? Double, let doubleRhs = rhsValue as? Double {
                        return doubleLhs < doubleRhs
                    } else if let floatLhs = lhsValue as? Float, let floatRhs = rhsValue as? Float {
                        return floatLhs < floatRhs
                    } else {
                        fatalError("Unsupported AdditiveArithmetic type")
                    }
                } else {
                    fatalError("Mismatched AdditiveArithmetic types")
                }
            } else {
                fatalError("Values are not of type AdditiveArithmetic")
            }
        }
        return false
    }

    static func <= (lhs: DictCBORSerializable, rhs: DictCBORSerializable) -> Bool {
        for (key, value) in rhs.data {
            if let lhsValue = lhs.data[key] as? (any AdditiveArithmetic),
               let rhsValue = value as? (any AdditiveArithmetic) {
                if type(of: lhsValue) == type(of: rhsValue) {
                    if let intLhs = lhsValue as? Int, let intRhs = rhsValue as? Int {
                        return intLhs <= intRhs
                    } else if let doubleLhs = lhsValue as? Double, let doubleRhs = rhsValue as? Double {
                        return doubleLhs <= doubleRhs
                    } else if let floatLhs = lhsValue as? Float, let floatRhs = rhsValue as? Float {
                        return floatLhs <= floatRhs
                    } else {
                        fatalError("Unsupported AdditiveArithmetic type")
                    }
                } else {
                    fatalError("Mismatched AdditiveArithmetic types")
                }
            } else {
                fatalError("Values are not of type AdditiveArithmetic")
            }
        }
        return false
    }
}
