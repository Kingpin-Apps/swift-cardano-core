import Foundation
import CryptoKit
import PotentCBOR

// MARK: - PlutusData
/// PlutusData is a helper class that can serialize itself into a CBOR format, which could be intepreted as
/// a data structure in Plutus scripts.
/// It is not required to use this class to interact with Plutus scripts. However, wrapping datum in PlutusData
/// class will reduce the complexity of serialization and deserialization tremendously.
class PlutusData: BaseArrayCBORSerializable {
    let MAX_BYTES_SIZE = 64
    
    /// Constructor ID of this plutus data.
    /// It is primarily used by Plutus core to reconstruct a data structure from serialized CBOR bytes.
    /// The default implementation is an almost unique, deterministic constructor ID in the range 1 - 2^32 based
    /// on class attributes, types and class name.
    class var CONSTR_ID: Any {
        let k = "_CONSTR_ID_\(String(describing: self))"
        
        let mirror = Mirror(reflecting: self)
        if !hasAttribute(self, propertyName: k) {
            let detString = try! idMap(cls: self, skipConstructor: true)
            let detHash = SHA256.hash(data: Data(detString.utf8)).map { String(format: "%02x", $0) }.joined()
            let _ = setAttribute(self, propertyName: k, value: Int(detHash, radix: 16)! % (1 << 32))
        }
        
        return getAttribute(self, propertyName: k)!
    }
    
    required init(_ fields: [Any]) throws {
        super.init()
        
        let validTypes: [Any.Type] = [
            PlutusData.self,
            Dictionary<AnyHashable, Any>.self,
            IndefiniteList<Any>.self,
            Int.self,
            ByteString.self,
            Data.self
        ]
        
        for field in fields {
            let fieldType = type(of: field)
            
            // Check if the field type is valid
            if !validTypes.contains(where: { $0 == fieldType }) {
                throw CardanoCoreError.typeError("Invalid field type: \(fieldType). A field in PlutusData should be one of \(validTypes).")
            }
            
            let _ = setAttribute(self, propertyName: String(describing: field), value: field)
            let data = getAttribute(self, propertyName: String(describing: field))!
            
            // Check if the data is a Data (byte array) and exceeds the allowed size
            if let data = field as? Data, data.count > MAX_BYTES_SIZE {
                throw CardanoCoreError.invalidArgument("The size of \(data) exceeds \(MAX_BYTES_SIZE) bytes. Use ByteString for long bytes.")
            }
        }
    }

    required init() {
        fatalError("init() has not been implemented")
    }
    
    func toShallowPrimitive() throws -> Any {
        var primitives: [Any] = []
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label, let value = child.value as? CBORSerializable {
                primitives.append(try! value.toShallowPrimitive())
            } else if child.value is NSNull {
                continue
            } else {
                primitives.append(child.value)
            }
        }
        
        let tag = getTag(constrID: Self.CONSTR_ID as! Int)
        
        if !primitives.isEmpty {
            let primitives = IndefiniteList(primitives)
            if tag != nil {
                return CBOR
                    .tagged(CBOR.Tag(rawValue: UInt64(tag!)), CBOR.fromAny(primitives))
            } else {
                return CBOR
                    .tagged(
                        CBOR.Tag(rawValue: UInt64(102)),
                        CBOR.fromAny([Self.CONSTR_ID, primitives])
                    )
            }
        } else {
            throw CardanoCoreError.valueError("Empty PlutusData.")
        }
    }

    override class func fromPrimitive<T>(_ value: Any) throws -> T {
        guard case let CBOR.tagged(tag, innerValue) = value else {
            throw CardanoCoreError.valueError("Expected tagged CBOR value.")
        }
        
        guard let innerTag = innerValue.unwrapped as? [Any] else {
            throw CardanoCoreError.valueError("Expected tagged CBOR value.")
        }
        
        if tag.rawValue == 102 {
            if innerTag[0] as! Int != Self.CONSTR_ID as! Int {
                throw CardanoCoreError.decodingError("Unexpected constructor ID for \(Self.self). Expected \(Self.CONSTR_ID), got \(innerTag[0]).")
            }
            
            guard innerTag.count == 2 else {
                throw CardanoCoreError.decodingError("Expect the length of value to be exactly 2, got \(innerTag.count).")
            }
            let primitive: BaseArrayCBORSerializable = try super.fromPrimitive(innerTag[1])
            return primitive as! T
        } else {
            let expectedTag = getTag(constrID: Self.CONSTR_ID as! Int)!
            if expectedTag != tag.rawValue {
                throw CardanoCoreError.decodingError("Unexpected constructor ID. Expected \(expectedTag), got \(tag.rawValue).")
            }
            let primitive: BaseArrayCBORSerializable = try super.fromPrimitive(innerTag)
            return primitive as! T
        }
        
    }
    
    func hash() throws -> DatumHash {
        return try datumHash(datum: .plutusData(self))
    }
    
    /// Convert to a dictionary.
    ///
    /// Reference of [Haskell's implementation](https://github.com/input-output-hk/cardano-node/blob/baa9b5e59c5d448d475f94cc88a31a5857c2bda5/cardano-api/src/Cardano/Api/ScriptData.hs#L449-L474)
    /// - Returns: A dictionary PlutusData that can be JSON encoded.
    func toDict() -> [String: Any] {
        func dfs(_ obj: Any) -> Any {
            // Check if the object is an Int
            if let intValue = obj as? Int {
                return ["int": intValue]
            }
            // Check if the object is Data (byte array)
            else if let byteArray = obj as? Data {
                return ["bytes": byteArray.map { String(format: "%02x", $0) }.joined()]
            }
            // Check if the object is a list or IndefiniteList
            else if let list = obj as? [Any] {
                return ["list": list.map { dfs($0) }]
            }
            // Check if the object is a dictionary
            else if let dict = obj as? [AnyHashable: Any] {
                return ["map": dict.map { ["k": dfs($0.key), "v": dfs($0.value)] }]
            }
            // Check if the object is of type PlutusData
            else if let plutusData = obj as? PlutusData {
                let mirror = Mirror(reflecting: plutusData)
                let fields = mirror.children.compactMap { child -> Any? in
                    if let label = child.label {
                        return dfs(child.value)
                    }
                    return nil
                }
                return [
                    "constructor": type(of: plutusData).CONSTR_ID,
                    "fields": fields
                ]
            }
            // Check if the object is of type RawPlutusData
            else if let rawPlutusData = obj as? RawPlutusData {
                return try! rawPlutusData.toDict()
            }
            // Check if the object is a RawCBOR
            else if let rawCBOR = obj as? CBOR {
                return try! RawPlutusData(data: .cbor(rawCBOR)).toDict()
            }
            // Raise an error for unexpected types
            else {
                fatalError("Unexpected type: \(type(of: obj))")
            }
        }

        return dfs(self) as! [String: Any]
    }
    
    /// Convert to a json string
    /// - Returns: A JSON encoded PlutusData.
    func toJSON() -> String {
        let dict = self.toDict()
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: jsonData, encoding: .utf8)!
    }
    
    /// Convert a dictionary to PlutusData
    /// - Parameter data: A dictionary representing the PlutusData.
    /// - Returns: Restored PlutusData.
    static func fromDict(_ data: [String: Any]) throws -> PlutusData {
        func dfs(_ obj: Any) throws -> Any {
            if let objDict = obj as? [String: Any] {
                if let constructor = objDict["constructor"] as? Int {
                    if constructor != (Self.CONSTR_ID as! Int) {
                        throw CardanoCoreError.decodingError(
                            "Mismatch between constructors in class \(Self.self), expect: \(Self.CONSTR_ID), got: \(constructor) instead."
                        )
                    }

                    var convertedFields: [Any] = []

                    // Assuming `fields()` is a method to retrieve field info.
                    // Replace `fields(cls)` logic with appropriate Swift implementation.
                    for fieldInfo in Mirror(reflecting: Self.self).children {
                        let fieldValue = objDict["fields"] as? [Any]
                        guard let f = fieldValue?[convertedFields.count] else {
                            throw CardanoCoreError.decodingError("Missing field data.")
                        }

                        // Type-specific handling
                        if let fieldType = fieldInfo.value as? PlutusData.Type {
                            convertedFields.append(try fieldType.fromDict(f as! [String: Any]))
                        } else if let fieldType = fieldInfo.value as? Datum.Type {
                            convertedFields.append(try RawPlutusData.fromDict(f as! [String: Any]))
                        } else if let fieldArray = f as? [Any] {
                            // List handling
                            convertedFields.append(try fieldArray.map { try dfs($0) })
                        } else if let fieldMap = f as? [[String: Any]] {
                            // Map handling
                            var convertedMap: [AnyHashable: Any] = [:]
                            for pair in fieldMap {
                                let key = try dfs(pair["k"]!)
                                let value = try dfs(pair["v"]!)
                                convertedMap[key as! AnyHashable] = value
                            }
                            convertedFields.append(convertedMap)
                        } else {
                            // Other types
                            convertedFields.append(try dfs(f))
                        }
                    }

                    // Initialize the PlutusData instance
                    // Replace `init` logic with actual initialization as needed.
                    return try Self.init(convertedFields)
                } else if let map = objDict["map"] as? [[String: Any]] {
                    var resultMap: [AnyHashable: Any] = [:]
                    for pair in map {
                        let key = try dfs(pair["k"]!)
                        let value = try dfs(pair["v"]!)
                        resultMap[key as! AnyHashable] = value
                    }
                    return resultMap
                } else if let intValue = objDict["int"] as? Int {
                    return intValue
                } else if let bytes = objDict["bytes"] as? String {
                    if bytes.count > 64 {
                        return  ByteString(value: Data(bytes.utf8))
                    } else {
                        return Data(Array(bytes.utf8))
                    }
                } else if let list = objDict["list"] as? [Any] {
                    return IndefiniteList(try list.map { try dfs($0) })
                } else {
                    throw CardanoCoreError.decodingError("Unexpected data structure: \(objDict)")
                }
            } else {
                throw CardanoCoreError.decodingError("Unexpected data type: \(type(of: obj))")
            }
        }

        return try dfs(data) as! PlutusData
    }
    
    /// Restore a json encoded string to a PlutusData.
    /// - Parameter data: An encoded json string.
    /// - Returns: The restored PlutusData.
    static func fromJSON(_ data: String) throws -> PlutusData {
        let jsonData = data.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        return try fromDict(dict)
    }
}
