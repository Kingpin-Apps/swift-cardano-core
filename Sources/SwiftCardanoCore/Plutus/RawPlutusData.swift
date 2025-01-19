import Foundation
import PotentCBOR
import PotentCodables

// MARK: - RawPlutusData
class RawPlutusData: Codable, Equatable {
    var data: RawDatum

    init(data: RawDatum) {
        self.data = data
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        return RawPlutusData(data: value as! RawDatum) as! T
//    }

    func toShallowPrimitive() throws -> Any {
        func dfs(_ obj: Any) -> Any {
            if let list = obj as? [AnyHashable] {
                let indefiniteList = try! IndefiniteList<AnyValue>(
                    from: list.map { dfs($0) as! AnyHashable } as! Decoder
                )
                return indefiniteList
            } else if let dict = obj as? [AnyHashable: Any] {
                return dict.reduce(into: [AnyHashable: Any]()) { result, pair in
                    result[dfs(pair.key as Any) as! AnyHashable] = dfs(pair.value)
                }
            } else if case let CBOR.tagged(tag, innerValue) = obj, let list = innerValue.unwrapped as? [Any] {
                let value: Any
                if tag.rawValue == 102 {
                    let indefiniteList = try! IndefiniteList<AnyValue>(
                        from: list.map { dfs($0) as! AnyValue } as! Decoder
                    )
                    
                    value = indefiniteList
                } else {
                    value = list.map { dfs($0) }
                }
                return CBORTag(tag: UInt64(tag.rawValue), value: CBOR.fromAny(value))
            }
            return obj
        }
        return dfs(self.data)
    }
    
    /// Convert to a dictionary.
    /// - Returns: A dict RawPlutusData that can be JSON encoded.
    func toDict() throws -> [String: Any] {
        func dfs(_ obj: Any) throws -> Any {
            if let intValue = obj as? Int {
                return ["int": intValue]
            } else if let byteArray = obj as? Data {
                return ["bytes": byteArray.toHex]
            } else if let list = obj as? [Any] {
                return ["list": try list.map { try dfs($0) }]
            } else if let list = obj as? IndefiniteList<AnyValue> {
                return ["list": try list.getAll().map { try dfs($0) }]
            } else if let dict = obj as? [AnyHashable: Any] {
                return ["map": try dict.map { ["k": try dfs($0.key), "v": try dfs($0.value)] }]
            } else if case let CBOR.tagged(tag, innerValue) = obj, let list = innerValue.unwrapped as? [Any]  {
                let (constructor, fields) = try getConstructorIDAndFields(
                    value: obj as! CBOR
                )
                return ["constructor": constructor, "fields": try fields.map { try dfs($0) }]
            } else {
                throw CardanoCoreError.typeError("Unexpected type: \(type(of: obj))")
            }
        }

        return try dfs(self.toShallowPrimitive()) as! [String: Any]
    }
    
    /// Convert to a json string
    /// - Returns: A JSON encoded RawPlutusData.
    func toJSON() throws -> String {
        let dict = try toDict()
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: jsonData, encoding: .utf8)!
    }

    /// Convert a dictionary to RawPlutusData
    /// - Parameter value: A dictionary.
    /// - Returns: Restored RawPlutusData.
    class func fromDict(_ data: [String: AnyHashable]) throws -> RawPlutusData {
        func dfs(_ obj: Any) throws -> Any {
            if let dict = obj as? [String: Any] {
                if let constructor = dict["constructor"] as? Int {
                    var convertedFields: [Any] = []
                    if let fields = dict["fields"] as? [Any] {
                        for field in fields {
                            convertedFields.append(try dfs(field))
                        }
                    }
                    if let tag = getTag(constrID: constructor) {
                        return CBORTag(
                            tag: UInt64(tag),
                            value: CBOR.fromAny(convertedFields)
                        )
                    } else {
                        return CBORTag(
                            tag: 102,
                            value: [
                                CBOR.fromAny(constructor),
                                CBOR.fromAny(try IndefiniteList<AnyValue>(
                                    from: convertedFields as! [AnyValue] as! Decoder
                                ))
                            ]
                        )
                    }
                } else if let map = dict["map"] as? [[String: AnyHashable]] {
                    var resultMap: [AnyHashable: Any] = [:]
                    for pair in map {
                        if let key = pair["k"], let value = pair["v"] {
                            resultMap[try dfs(key) as! AnyHashable] = try dfs(value)
                        }
                    }
                    return resultMap
                } else if let intValue = dict["int"] as? Int {
                    return intValue
                } else if let bytes = dict["bytes"] as? String {
                    if bytes.count > 64 {
                        return ByteString(value: Data(bytes.utf8))
                    } else {
                        return Data(bytes.utf8)
                    }
                } else if let list = dict["list"] as? [Any] {
                    return try IndefiniteList<AnyValue>(
                        from: try list.map { try dfs(
                            $0
                        )
                        } as! [AnyHashable] as! Decoder)
                } else {
                    throw CardanoCoreError.deserializeError("Unexpected data structure: \(dict)")
                }
            } else {
                throw CardanoCoreError.typeError("Unexpected data type: \(type(of: obj))")
            }
        }

        return RawPlutusData(data: try dfs(data) as! RawDatum)
    }
    
    /// Restore a json encoded string to a RawPlutusData.
    /// - Parameter json: An encoded json string.
    /// - Returns: The restored RawPlutusData.
    class func fromJSON(_ json: String) throws -> RawPlutusData {
        guard let jsonData = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyHashable] else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
        return try fromDict(dict)
    }
    
    static func == (lhs: RawPlutusData, rhs: RawPlutusData) -> Bool {
        lhs.data == rhs.data
    }
}
