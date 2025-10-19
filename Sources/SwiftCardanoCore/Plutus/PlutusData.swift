//import BigInt
//import Foundation
//import OrderedCollections
//import PotentCBOR
//import PotentCodables
//#if canImport(CryptoKit)
//import CryptoKit
//#elseif canImport(Crypto)
//import Crypto
//#endif
//
//// MARK: - PlutusDataClass
//
///// PlutusData is a helper class that can serialize itself into a CBOR format, which could be intepreted as
///// a data structure in Plutus scripts.
///// It is not required to use this class to interact with Plutus scripts. However, wrapping datum in PlutusData
///// class will reduce the complexity of serialization and deserialization tremendously.
//@dynamicMemberLookup
//open class PlutusData: CBORSerializable {
//    public static let MAX_BYTES_SIZE = 64
//    
//    public var fields: [Any]
//    
//    public subscript(dynamicMember member: String) -> Any {
//        get {
//            self.fields.first(where: { String(describing: $0) == member })!
//        }
//        set {
//            self.fields = self.fields.map { String(describing: $0) == member ? newValue : $0 }
//        }
//    }
//    
//    public required init() {
//        self.fields = []
//    }
//    
//    public required init(fields: [Any]) throws {
//        let validTypes: [Any.Type] = [
//            AnyValue.self,
//            PlutusData.self,
//            Dictionary<AnyValue, AnyValue>.self,
//            OrderedDictionary<AnyValue, AnyValue>.self,
//            IndefiniteList<AnyValue>.self,
//            Array<AnyValue>.self,
//            Int.self,
//            Int64.self,
//            UInt64.self,
//            ByteString.self,
//            Data.self,
//        ]
//        
//        for field in fields {
//            let fieldType = type(of: field)
//            
//            // Check if the field type is valid
//            if let fieldClass = fieldType as? AnyClass {
//                if !validTypes.contains(where: { valid in
//                    if let validClass = valid as? AnyClass {
//                        return fieldClass == validClass || isSubclassOf(fieldClass, validClass)
//                    }
//                    return false
//                }) {
//                    throw CardanoCoreError.typeError("Invalid field type: \(fieldClass)")
//                }
//            } else if !validTypes.contains(where: { $0 == fieldType }) {
//                throw CardanoCoreError.typeError(
//                    "Invalid field type: \(fieldType). A field in PlutusData should be one of \(validTypes)."
//                )
//            }
//            
//            //            let _ = setAttribute(self, propertyName: String(describing: field), value: field)
//            //            _ = getAttribute(self, propertyName: String(describing: field))!
//            
//            // Check if the data is a Data (byte array) and exceeds the allowed size
//            if let data = field as? Data, data.count > Self.MAX_BYTES_SIZE {
//                throw CardanoCoreError.invalidArgument(
//                    "The size of \(data) exceeds \(Self.MAX_BYTES_SIZE) bytes. Use ByteString for long bytes."
//                )
//            }
//        }
//        
//        self.fields = fields
//    }
//    
//    open var constrID: Int {
//        let detString = try! idMap(cls: Self.self, skipConstructor: true)
//        let detHash = SHA256.hash(data: Data(detString.utf8)).map { String(format: "%02x", $0) }
//            .joined()
//        let num = BigInt(detHash, radix: 16)
//        let calc = num! % (1 << 32)
//        
//        return Int(calc)
//    }
//    
//    open class var CONSTR_ID: Int {
//        return Self().constrID
//    }
//    
//    public func toAnyValue() -> AnyValue {
//        return AnyValue.array(
//            fields.map {
//                if let plutusData = $0 as? PlutusData {
//                    return plutusData.toAnyValue()
//                } else if let orderedDict = $0 as? OrderedDictionary<AnyValue, AnyValue> {
//                    // Handle OrderedDictionary<AnyValue, AnyValue> directly to avoid optional wrapping
//                    return AnyValue.dictionary(orderedDict)
//                } else if let dict = $0 as? [AnyValue: AnyValue] {
//                    return AnyValue.dictionary(
//                        OrderedDictionary(
//                            uniqueKeysWithValues: dict.map {
//                                ($0.key, $0.value)
//                            }
//                        )
//                    )
//                } else if let array = $0 as? [AnyValue] {
//                    return AnyValue.array(array)
//                } else if let array = $0 as? [Any] {
//                    return AnyValue.array(array.map { try! AnyValue.wrapped($0) })
//                } else {
//                    return try! AnyValue.wrapped($0)
//                }
//            }
//        )
//    }
//    
//    public func toShallowPrimitive() throws -> CBORTag {
//        
//        let mirror = Mirror(reflecting: self)
//        
//        let primitives = try mirror.children.map { field -> AnyValue in
//            if let plutusData = field.value as? PlutusData {
//                return try AnyValue.Encoder().encode(plutusData.toShallowPrimitive().toCBORData())
//            } else if let list = field.value as? IndefiniteList<AnyValue> {
//                return try AnyValue.indefiniteArray( list.map { try AnyValue.wrapped($0) })
//            } else if let codable = field.value as? Codable {
//                return try AnyValue.Encoder().encode(codable)
//            } else if let orderedDict = field.value as? OrderedDictionary<AnyValue, AnyValue> {
//                // Handle OrderedDictionary<AnyValue, AnyValue> directly to avoid optional wrapping
//                return AnyValue.dictionary(orderedDict)
//            } else if let dict = field.value as? [AnyValue: AnyValue] {
//                return AnyValue.dictionary(
//                    OrderedDictionary(
//                        uniqueKeysWithValues: dict.map {
//                            ($0.key, $0.value)
//                        }
//                    )
//                )
//            } else {
//                return try AnyValue.wrapped(field.value)
//            }
//        }
//        let tag = getTag(constrID: Self.CONSTR_ID)
//        
//        if let tag = tag {
//            return CBORTag(tag: UInt64(tag), value: AnyValue.array(primitives))
//        } else {
//            return CBORTag(
//                tag: 102,
//                value: .array([.int(Self.CONSTR_ID), .array(primitives)]))
//        }
//    }
//    
//    public required convenience init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let value = try container.decode(CBOR.self)
//        
//        guard case CBOR.tagged(_, _) = value else {
//            throw CardanoCoreError.deserializeError(
//                "Value does not match the data schema of PlutusData.")
//        }
//        
//        let (constrID, fields) = try getConstructorIDAndFields(value: value)
//        
//        if constrID != Self.CONSTR_ID {
//            throw CardanoCoreError.decodingError(
//                "Unexpected constructor ID for \(Self.self). Expect \(Self.CONSTR_ID), got \(constrID) instead."
//            )
//        }
//        
//        try self.init(fields: fields)
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        
//        let mirror = Mirror(reflecting: self)
//        
//        var primitives: [AnyHashable] = []
//        
//        for field in mirror.children {
//            
//            if field.label == "fields" {
//                if let array = field.value as? [Any] {
//                    for item in array {
//                        if let plutusData = item as? PlutusData {
//                            primitives.append(try plutusData.toShallowPrimitive())
//                        }  else if let int = item as? Int {
//                            primitives.append(int)
//                        } else if let hashable = item as? AnyHashable {
//                            primitives.append(hashable)
//                        } else {
//                            primitives.append(try AnyValue.wrapped(item))
//                        }
//                    }
//                } else {
//                    primitives.append(try AnyValue.wrapped(field.value))
//                }
//            } else if let plutusData = field.value as? PlutusData {
//                primitives.append(try plutusData.toShallowPrimitive())
//            } else if let array = field.value as? IndefiniteList<AnyValue> {
//                //                primitives.append( AnyValue.indefiniteArray(try array.map { try AnyValue.wrapped($0) }))
//                //                primitives.append(try CBOR.Encoder().encode(array))
//                primitives.append(array)
//                //                primitives.append(try array.toCBOR().toCBOR)
//            } else if let mirror = Mirror(reflecting: field.value).displayStyle,
//                      mirror == .dictionary
//            {
//                let orderedDict: OrderedDictionary<AnyHashable, AnyHashable>
//                
//                // Handle any type of dictionary by converting it to OrderedDictionary<AnyHashable, AnyHashable>
//                if let dict = field.value as? [AnyHashable: AnyHashable] {
//                    orderedDict = OrderedDictionary(
//                        uniqueKeysWithValues: dict.map {
//                            ($0.key, $0.value)
//                        }
//                    )
//                } else if let dict = field.value as? OrderedDictionary<AnyHashable, AnyHashable> {
//                    orderedDict = OrderedDictionary(
//                        uniqueKeysWithValues: dict.map {
//                            ($0.key, $0.value)
//                        }
//                    )
//                } else {
//                    // For any other dictionary type, we'll convert it to OrderedDictionary<AnyHashable, AnyHashable>
//                    let mirror = Mirror(reflecting: field.value)
//                    var tempDict = OrderedDictionary<AnyHashable, AnyHashable>()
//                    
//                    for child in mirror.children {
//                        if let value = child.value as? (key: AnyHashable, value: AnyHashable) {
//                            tempDict[value.key] = value.value
//                        }
//                    }
//                    
//                    orderedDict = tempDict
//                }
//                
//                let toAppend = OrderedDictionary<AnyHashable, AnyHashable>(
//                    uniqueKeysWithValues: try orderedDict.map {
//                        
//                        let key: AnyHashable
//                        let value: AnyHashable
//                        
//                        if let intKey = $0.key as? Int {
//                            key = intKey
//                        } else if let stringKey = $0.key as? String {
//                            key = stringKey
//                        } else if let any = $0.key as? AnyValue {
//                            key = any
//                        } else if let encodableKey = $0.key as? Encodable {
//                            key = try CBOREncoder().encode(encodableKey)
//                        } else {
//                            throw CardanoCoreError.encodingError(
//                                "Invalid key type: \($0.key)"
//                            )
//                        }
//                        
//                        if let plutusData = $0.value as? PlutusData {
//                            value = try plutusData.toShallowPrimitive()
//                        } else if let intValue = $0.value as? Int {
//                            value = intValue
//                        } else if let stringValue = $0.value as? String {
//                            value = stringValue
//                        } else if let any = $0.value as? AnyValue {
//                            value = any
//                        } else if let codable = $0.value as? Codable {
//                            value = try CBOR.Encoder().encode(codable)
//                        } else if let dictValue = $0.value as? [AnyHashable: Any] {
//                            // Handle nested dictionaries
//                            value = try OrderedDictionary(
//                                uniqueKeysWithValues: dictValue.map { key, val in
//                                    (key, try AnyValue.wrapped(val))
//                                }
//                            )
//                        } else {
//                            value = try AnyValue.wrapped($0.value)
//                        }
//                        
//                        return (key, value)
//                    }
//                )
//                primitives.append(toAppend)
//            }
//            else if isArray(field.value) {
//                
//                var list: [AnyHashable] = []
//                let mir =  Mirror(reflecting: field.value)
//                for child in mir.children {
//                    if let item = child.value as? PlutusData {
//                        list.append(try item.toShallowPrimitive())
//                    } else {
//                        list.append(try AnyValue.wrapped(child.value))
//                    }
//                }
//                primitives.append(list)
//            }
//            else if let array = field.value as? [PlutusData] {
//                primitives.append( try array.map { try $0.toShallowPrimitive() })
//            } else if let array = field.value as? IndefiniteList<PlutusData> {
//                primitives.append( try array.map { try $0.toShallowPrimitive() })
//            } else if let array = field.value as? IndefiniteList<AnyHashable> {
//                primitives.append( try array.map { try AnyValue.wrapped($0) })
//            } else if let array = field.value as? [Any] {
//                primitives.append( try array.map { try AnyValue.wrapped($0) })
//            } else if let int = field.value as? Int {
//                primitives.append( AnyValue.int(int))
//            } else if let int = field.value as? Data {
//                primitives.append( AnyValue.data(int))
//            } else if let codable = field.value as? Codable {
//                primitives.append(try CBOR.Encoder().encode(codable))
//            } else if isEnum(field.value), let info = extractEnumInfo((field.value)) {
//                if let codable = info.associatedValue as? Codable {
//                    primitives.append(try CBOR.Encoder().encode(codable).toCBOR)
//                } else if let plutusData = info.associatedValue as? PlutusData {
//                    primitives.append(try plutusData.toShallowPrimitive())
//                } else {
//                    primitives.append(try AnyValue.wrapped(info.associatedValue).toCBORData().toCBOR)
//                }
//            } else {
//                primitives.append(try AnyValue.wrapped(field.value).toCBORData().toCBOR)
//            }
//        }
//        
//        let tag = getTag(constrID: Self.CONSTR_ID)
//        
//        let toEncode: CBOR
//        if primitives.isEmpty {
//            toEncode = .array([])
//        } else {
//            let indefiniteList = IndefiniteList<AnyHashable>(primitives)
//            toEncode = try indefiniteList.toCBORData().toCBOR
//        }
//        
//        if let tag = tag {
//            try container.encode(
//                CBOR.tagged(
//                    CBOR.Tag(rawValue: UInt64(tag)),
//                    toEncode
//                )
//            )
//        } else {
//            try container.encode(
//                CBOR.tagged(
//                    CBOR.Tag(rawValue: 102),
//                    try! CBOREncoder().encode(
//                        CBOR.array([
//                            CBOR(Self.CONSTR_ID),
//                            toEncode,
//                        ])
//                    ).toCBOR
//                )
//            )
//        }
//    }
//    
//    public func hash() throws -> DatumHash {
//        return try datumHash(datum: .plutusData(self))
//    }
//    
//    /// Decodes a dictionary representation (potentially from JSON) back into the corresponding Swift value.
//    /// Handles primitives (int, bytes), lists, maps, and nested PlutusData objects.
//    /// NOTE: Decoding nested PlutusData objects (identified by "constructor" key) relies on
//    /// the static `PlutusData.fromDict` method, which in turn requires a mechanism
//    /// (like a hypothetical `PlutusRegistry`) to map constructor IDs to specific PlutusData subclass types.
//    private static func decodeValue(obj: Any) throws -> Any {
//        if let dict = obj as? [String: Any] {
//            
//            if let constructor = dict["constructor"] as? Int {
//                
//                guard constructor == Self.self.CONSTR_ID else {
//                    throw CardanoCoreError.decodingError(
//                        "Mismatch between constructors in \(self), expect: \(Self.self.CONSTR_ID), got: \(constructor) instead."
//                    )
//                }
//                
//                // Ensure fields exist and are an array
//                guard let fields = dict["fields"] as? [Any] else {
//                    throw CardanoCoreError.decodingError("Missing fields data.")
//                }
//                
//                // Create an instance to inspect its fields
//                let instance = Self.init()
//                let mirror = Mirror(reflecting: instance)
//                var convertedFields = [] as [AnyValue]
//                
//                // Process each field based on its type
//                for (field, value) in zip(mirror.children, fields) {
//                    if let plutusField = field.value as? PlutusData {
//                        // Handle PlutusData subclass fields
//                        let plutusType = Swift.type(
//                            of: plutusField
//                        )
//                        
//                        let decodedSubData = try plutusType.init(from: value as! [String: Any])
//                            .toAnyValue()
//                        convertedFields.append(decodedSubData)  // Append the decoded object
//                    } else if field.value is Datum {
//                        convertedFields.append(try AnyValue.wrapped(value))
//                        //                        convertedFields.append(
//                        //                            try RawPlutusData.fromDict(value as! [String: Any])).toAnyValue()
//                    } else if let mapValue = value as? [String: Any], mapValue["map"] != nil {
//                        
//                        let fieldValue: [AnyHashable: Any]
//                        let mapItems = mapValue["map"] as! [[String: Any]]
//                        var result = OrderedDictionary<AnyValue, AnyValue>()
//                        
//                        if let fv = field.value as? [AnyHashable: Any]? {
//                            fieldValue = fv!
//                        } else if isDictionary(field.value) {
//                            let mirror = Mirror(reflecting: field.value)
//                            
//                            fieldValue = Dictionary<AnyHashable, Any>(
//                                uniqueKeysWithValues: try mirror.children.map {
//                                    guard let pair = $0.value as? (key: AnyHashable, value: Any) else {
//                                        throw CardanoCoreError.typeError(
//                                            "Invalid field type: \(type(of: field.value)). Expected [AnyHashable: Any]."
//                                        )
//                                    }
//                                    return (pair.key, pair.value)
//                                }
//                            )
//                        }  else {
//                            throw CardanoCoreError.typeError(
//                                "Invalid field type: \(type(of: field.value)). Expected [AnyValue: AnyValue]."
//                            )
//                        }
//                        
//                        for item in mapItems {
//                            guard let k = item["k"], let v = item["v"] else {
//                                throw CardanoCoreError.decodingError(
//                                    "Invalid map entry: \(item)")
//                            }
//                            
//                            var key: AnyValue
//                            var value: AnyValue
//                            
//                            if let plutusField = fieldValue.keys.first as? PlutusData {
//                                let plutusType = Swift.type(of: plutusField)
//                                key = try plutusType.init(from: k as! [String: Any]).toAnyValue()
//                            } else {
//                                key = try AnyValue.wrapped(try decodeValue(obj: k))
//                            }
//                            
//                            if let plutusField = fieldValue.values.first as? PlutusData {
//                                let plutusType = type(
//                                    of: plutusField
//                                )
//                                
//                                let decodedNested = try plutusType.init(from: v as! [String: Any])
//                                value = decodedNested.toAnyValue()  // Use the decoded object
//                            } else {
//                                value = try AnyValue.wrapped(try decodeValue(obj: v))
//                            }
//                            
//                            result[key] = value
//                        }
//                        convertedFields.append(try AnyValue.wrapped(result))
//                    } else if let listValue = value as? [String: Any], listValue["list"] != nil {
//                        // Handle array types
//                        let items = listValue["list"] as! [Any]
//                        let convertedItems = try items.map {
//                            if field.value is [AnyValue] {
//                                return try decodeValue(obj: $0)
//                            } else if let plutusFields = field.value as? [PlutusData] {
//                                let plutusType = type(of: plutusFields.first!)
//                                return try plutusType.init(from: $0 as! [String: Any]).toAnyValue()
//                            } else if isArray(field.value) {
//                                
//                                var list: [AnyHashable] = []
//                                let mir =  Mirror(reflecting: field.value)
//                                for child in mir.children {
//                                    if let item = child.value as? PlutusData {
//                                        let plutusType = type(of: item)
//                                        list.append(try plutusType.init(from: $0 as! [String: Any]).toAnyValue())
//                                    } else {
//                                        list
//                                            .append(
//                                                try decodeValue(
//                                                    obj: child.value
//                                                ) as! AnyHashable
//                                            )
//                                    }
//                                }
//                                return list
//                            } else {
//                                return try decodeValue(obj: $0)
//                            }
//                        }
//                        convertedFields.append(try AnyValue.wrapped(convertedItems))
//                    } else if let intValue = value as? [String: Any],
//                              let intVal = intValue["int"] as? Int
//                    {
//                        convertedFields.append(AnyValue(integerLiteral: intVal))
//                    } else if let bytesValue = value as? [String: Any],
//                              let bytesStr = bytesValue["bytes"] as? String
//                    {
//                        convertedFields.append(try AnyValue.wrapped(Data(hex: bytesStr)))
//                    } else if isEnum(field.value), let info = extractEnumInfo((field.value)) {
//                        if let plutusField = info.associatedValue as? PlutusData {
//                            let plutusType = type(of: plutusField)
//                            convertedFields.append(try plutusType.init(from: value as! [String: Any]).toAnyValue())
//                        } else {
//                            convertedFields.append(try decodeValue(obj: value) as! AnyValue)
//                        }
//                    } else {
//                        // Handle other types recursively
//                        convertedFields
//                            .append(try decodeValue(obj: value) as! AnyValue)
//                    }
//                }
//                
//                //                return try Self.init(fields: convertedFields).toAnyValue()
//                return convertedFields
//                
//            } else if let mapArray = dict["map"] as? [[String: Any]] {
//                var result = OrderedDictionary<AnyValue, AnyValue>()
//                for pair in mapArray {
//                    guard let k = pair["k"], let v = pair["v"] else {
//                        throw CardanoCoreError.decodingError("Invalid map entry: \(pair)")
//                    }
//                    let key = try decodeValue(obj: k)  // Recurse
//                    let value = try decodeValue(obj: v)  // Recurse
//                    // Wrap results in AnyValue for the dictionary
//                    result[try AnyValue.wrapped(key)] = try AnyValue.wrapped(value)
//                }
//                return result  // Return OrderedDictionary<AnyValue, AnyValue>
//            } else if let listArray = dict["list"] as? [Any] {
//                // Recursively decode list items and return as [Any]
//                return try listArray.map { try decodeValue(obj: $0) }
//            } else if let intVal = dict["int"] {
//                if let int = intVal as? Int { return int }
//                if let int64 = intVal as? Int64 { return int64 }
//                // Handle Doubles that might come from JSON parsing if they represent integers
//                if let dbl = intVal as? Double, dbl == floor(dbl) { return Int(dbl) }
//                throw CardanoCoreError.decodingError("Invalid int value: \(intVal)")
//            } else if let bytesStr = dict["bytes"] as? String {
//                return Data(hex: bytesStr)  // Return Data
//            } else {
//                throw CardanoCoreError.decodingError("Unexpected dictionary structure: \(dict)")
//            }
//        } else if let array = obj as? [Any] {
//            // Handle plain arrays potentially coming directly from JSON for list fields
//            return try array.map { try decodeValue(obj: $0) }
//        } else if obj is Int || obj is Int64 {
//            return obj  // Return primitive integers
//        } else if obj is Data {
//            return obj  // Return primitive data (less likely if source follows {"bytes":..} schema)
//        }
//        // Handle other JSON primitives if necessary, though Plutus schema is specific
//        else if obj is String || obj is Double || obj is Bool || obj is NSNull {
//            throw CardanoCoreError.decodingError(
//                "Unsupported primitive type \(type(of: obj)) found in dictionary representation. Expected int, bytes, list, map, or constructor."
//            )
//        } else {
//            throw CardanoCoreError.typeError(
//                "Unexpected data type during dict decode: \(type(of: obj)) for value \(obj)")
//        }
//    }
//    
//    /// Initializes a PlutusData instance from a dictionary representation (e.g., obtained from `toJSON`).
//    ///
//    /// This initializer expects the dictionary to have a "constructor" key matching `Self.CONSTR_ID`
//    /// and a "fields" key containing an array of values representing the fields. It uses
//    /// a helper method (`decodeValue`) to convert the field values back into Swift types.
//    ///
//    /// - Parameter dict: A dictionary containing "constructor" and "fields" keys.
//    /// - Throws: `CardanoCoreError` if the dictionary format is invalid, constructor ID mismatches,
//    ///           or decoding of field values fails. Note that decoding nested PlutusData objects
//    ///           currently relies on the static `fromDict` method and may require a type registry.
//    public required convenience init(from dict: [String: Any]) throws {
//        let vals = try Self.decodeValue(obj: dict)
//        if let vals = vals as? AnyValue, let array = vals.arrayValue {
//            try self.init(fields: array)
//        } else if let vals = vals as? [Any] {
//            try self.init(fields: vals)
//        } else {
//            throw CardanoCoreError.decodingError(
//                "Invalid dictionary format for PlutusData: \(dict)"
//            )
//        }
//    }
//    
//    /// Convert to a dictionary.
//    ///
//    /// Reference of [Haskell's implementation](https://github.com/input-output-hk/cardano-node/blob/baa9b5e59c5d448d475f94cc88a31a5857c2bda5/cardano-api/src/Cardano/Api/ScriptData.hs#L449-L474)
//    /// - Returns: A dictionary PlutusData that can be JSON encoded.
//    public func toDict() throws -> [String: Any] {
//        func dfs(_ anyObj: Any) throws -> Any {
//            
//            var obj: Any = anyObj
//            if let anyValue = anyObj as? AnyValue {
//                obj = anyValue.unwrapped!
//            }
//            
//            if let intValue = obj as? Int {
//                return ["int": intValue]
//            } else if let intValue = obj as? Int64 {
//                return ["int": intValue]
//            } else if let byteArray = obj as? Data {
//                return ["bytes": byteArray.map { String(format: "%02x", $0) }.joined()]
//            } else if let dict = obj as? [AnyHashable: Any] {
//                return [
//                    "map": try dict.map { ["k": try dfs($0.key.base), "v": try dfs($0.value)] }
//                ]
//            } else if let plutusData = obj as? PlutusData {
//                let mirror = Mirror(reflecting: obj)
//                return [
//                    "constructor": type(of: plutusData).CONSTR_ID,
//                    "fields": try mirror.children.map { try dfs($0.value) },
//                ]
//            } else if let rawPlutusData = obj as? RawPlutusData {
//                return ["raw": rawPlutusData.data]
//            } else if let rawCBOR = obj as? CBOR {
//                return ["cbor": rawCBOR]
//            } else if isArray(obj) {
//                let mirror =  Mirror(reflecting: obj)
//                return  ["list": try mirror.children.map { try dfs($0.value) }]
//            } else if isDictionary(obj) {
//                var result: [[String: Any]] = []
//                
//                let mirror = Mirror(reflecting: obj)
//                for child in mirror.children {
//                    if let pair = child.value as? (key: Any, value: Any) {
//                        let k = try dfs(pair.key)
//                        let v = try dfs(pair.value)
//                        result.append(["k": k, "v": v])
//                    }
//                }
//                
//                return ["map": result]
//            } else if isEnum(obj), let info = extractEnumInfo((obj)) {
//                return  try dfs(info.associatedValue)
//            } else if let list = obj as? [Any] {
//                return  ["list": try list.map { try dfs($0) }]
//            } else if let list = obj as? IndefiniteList<AnyValue> {
//                return  ["list": try list.map { try dfs($0) }]
//            } else {
//                throw
//                CardanoCoreError
//                    .encodingError("Unexpected type: \(type(of: obj)) for \(obj)")
//            }
//        }
//        
//        return try dfs(self) as! [String: Any]
//    }
//    
//    /// Convert to a json string
//    /// - Returns: A JSON encoded PlutusData.
//    public func toJSON() throws -> String {
//        let dict = try self.toDict()
//        let jsonData = try JSONSerialization.data(
//            withJSONObject: dict,
//            options: [.sortedKeys]
//        )
//        return String(data: jsonData, encoding: .utf8)!
//    }
//    
//    /// Convert a dictionary to PlutusData
//    /// - Parameter data: A dictionary representing the PlutusData.
//    /// - Returns: Restored PlutusData.
//    public class func fromDict<T: PlutusData>(_ data: [String: Any]) throws -> T {
//        return try Self.init(from: data) as! T
//    }
//    
//    /// Restore a json encoded string to a PlutusData.
//    /// - Parameter data: An encoded json string.
//    /// - Returns: The restored PlutusData.
//    public class func fromJSON(_ data: String) throws -> Self {
//        let jsonData = data.data(using: .utf8)!
//        let dict =
//        try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
//        return try Self.init(from: dict)
//    }
//    
//    public func hash(into hasher: inout Hasher) {
//        for field in fields {
//            if let hashable = field as? AnyHashable {
//                hasher.combine(hashable)
//            }
//        }
//    }
//    
//    public static func == (lhs: PlutusData, rhs: PlutusData) -> Bool {
//        guard lhs.fields.count == rhs.fields.count else { return false }
//        
//        func normalizeField(_ field: Any) -> Any {
//            if let anyValue = field as? AnyValue {
//                return anyValue.normalized()
//            } else if let indefiniteList = field as? IndefiniteList<AnyValue> {
//                return IndefiniteList<AnyValue>(indefiniteList.map { $0.normalized() })
//            }
//            return field
//        }
//        
//        for (lhsField, rhsField) in zip(lhs.fields, rhs.fields) {
//            let normalizedLhs = normalizeField(lhsField)
//            let normalizedRhs = normalizeField(rhsField)
//            
//            if let lhsHashable = normalizedLhs as? AnyHashable,
//               let rhsHashable = normalizedRhs as? AnyHashable {
//                if lhsHashable != rhsHashable {
//                    return false
//                }
//            } else {
//                return false
//            }
//        }
//        
//        return true
//    }
//    
//    /// Creates a PlutusData instance from a CBORTag primitive.
//    /// - Parameter value: The CBORTag value to deserialize from.
//    /// - Returns: A new PlutusData instance.
//    /// - Throws: CardanoCoreError if the deserialization fails.
//    public class func fromPrimitive(_ value: CBORTag) throws -> Self {
//        if value.tag == 102 {
//            guard let valueArray = value.value.arrayValue,
//                  valueArray.count == 2,
//                  let tag = valueArray[0].integerValue(UInt64.self)
//            else {
//                throw CardanoCoreError.deserializeError(
//                    "Invalid CBORTag format for PlutusData. Expected array of length 2 with integer tag but got: \(value)"
//                )
//            }
//            
//            if tag != Self.CONSTR_ID {
//                throw CardanoCoreError.decodingError(
//                    "Unexpected constructor ID for \(Self.self). Expect \(Self.CONSTR_ID), got \(tag) instead."
//                )
//            }
//            
//            guard let fields = valueArray[1].arrayValue ?? valueArray[1].indefiniteArrayValue else {
//                throw CardanoCoreError.deserializeError("Expected array of fields but got: \(valueArray[1])")
//            }
//            
//            return try Self(
//                fields: fields.map {
//                    $0.unwrapped! as Any
//                })
//        } else {
//            let expectedTag = getTag(constrID: Self.CONSTR_ID)
//            
//            if expectedTag != Int(value.tag) {
//                throw CardanoCoreError.decodingError(
//                    "Unexpected constructor ID for \(Self.self). Expect \(expectedTag ?? -1), got \(value.tag) instead."
//                )
//            }
//            
//            guard let fields = value.value.arrayValue else {
//                throw CardanoCoreError.deserializeError("Expected array of fields.")
//            }
//            
//            return try Self(
//                fields: fields.map {
//                    $0.unwrapped! as! any Codable
//                })
//        }
//    }
//    
//    /// Initializes PlutusData from a Primitive value.
//    /// - Parameter primitive: The Primitive to convert from.
//    /// - Throws: CardanoCoreError if the conversion fails.
//    public required convenience init(from primitive: Primitive) throws {
//        switch primitive {
//            case .cborTag(let tag):
//                // Handle CBORTag - the main way PlutusData is represented
//                let instance = try Self.fromPrimitive(tag)
//                try self.init(fields: instance.fields)
//                
//            case .list(let array):
//                // Handle direct list representation
//                let convertedFields = try array.map { primitive -> Any in
//                    switch primitive {
//                        case .plutusData(let plutusData):
//                            return plutusData
//                        default:
//                            return try AnyValue(from: primitive)
//                    }
//                }
//                try self.init(fields: convertedFields)
//                
//            case .dict(let dictionary):
//                // Handle dictionary representation (less common for PlutusData)
//                if let constructorPrimitive = dictionary[.int(121)], // "constructor" key as int
//                   case .int(let constructorID) = constructorPrimitive,
//                   constructorID == Self.CONSTR_ID,
//                   let fieldsPrimitive = dictionary[.int(102)], // "fields" key as int
//                   case .list(let fieldsArray) = fieldsPrimitive {
//                    
//                    let convertedFields = try fieldsArray.map { primitive -> Any in
//                        switch primitive {
//                            case .plutusData(let plutusData):
//                                return plutusData
//                            default:
//                                return try AnyValue(from: primitive)
//                        }
//                    }
//                    try self.init(fields: convertedFields)
//                } else {
//                    throw CardanoCoreError.deserializeError(
//                        "Invalid dictionary format for PlutusData conversion"
//                    )
//                }
//                
//            case .plutusData(let plutusData):
//                // Direct PlutusData case
//                if type(of: plutusData) == Self.self {
//                    try self.init(fields: plutusData.fields)
//                } else {
//                    throw CardanoCoreError.typeError(
//                        "PlutusData type mismatch: expected \(Self.self), got \(type(of: plutusData))"
//                    )
//                }
//                
//            default:
//                throw CardanoCoreError.deserializeError(
//                    "Cannot convert Primitive.\(primitive) to PlutusData"
//                )
//        }
//    }
//    
//    /// Converts PlutusData to a Primitive representation.
//    /// - Returns: A Primitive representation of this PlutusData.
//    public func toPrimitive() throws -> Primitive {
//        // Convert PlutusData to its primitive representation using CBORTag
//        let tag = getTag(constrID: Self.CONSTR_ID)
//        
//        // Convert fields to primitive representations
//        let primitiveFields = try fields.map { field -> Primitive in
//            return try Primitive.fromAny(field)
//        }
//        
//        // Create CBORTag with the appropriate tag and field array
//        let fieldsArray = AnyValue.array(try! primitiveFields.map { try AnyValue(from: $0) })
//        
//        let cborTag: CBORTag
//        if let tag = tag {
//            cborTag = CBORTag(tag: UInt64(tag), value: fieldsArray)
//        } else {
//            // Use alternative format for constructor IDs >= 128
//            let constructorArray = AnyValue.array([.int(Self.CONSTR_ID), fieldsArray])
//            cborTag = CBORTag(tag: 102, value: constructorArray)
//        }
//        
//        return .cborTag(cborTag)
//    }
//}
//
//// MARK: - Unit
//
///// The default "Unit type" with a 0 constructor ID
////public final class Unit: PlutusData {
////    override public class var CONSTR_ID: Int { return 0 }
////    
////    public required init() {
////        try! super.init(fields: [])
////    }
////    
////    public required init(fields: [Any]) throws {
////        try super.init(fields: fields)
////    }
////}
