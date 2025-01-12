import Foundation
import PotentCBOR

// MARK: - RawPlutusData
class RawPlutusData: CBORSerializable {

    var data: RawDatum

    init(data: RawDatum) {
        self.data = data
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        return RawPlutusData(data: value as! RawDatum) as! T
    }

    func toShallowPrimitive() throws -> Any {
        func dfs(_ obj: Any) -> Any {
            if let list = obj as? [Any] {
                let indefiniteList = IndefiniteList(list.map { dfs($0) })
                return indefiniteList
            } else if let dict = obj as? [AnyHashable: Any] {
                return dict.reduce(into: [AnyHashable: Any]()) { result, pair in
                    result[dfs(pair.key as Any) as! AnyHashable] = dfs(pair.value)
                }
            } else if case let CBOR.tagged(tag, innerValue) = obj, let list = innerValue.unwrapped as? [Any] {
                let value: Any
                if tag.rawValue == 102 {
                    let indefiniteList = IndefiniteList(list.map { dfs($0) })
                    value = indefiniteList
                } else {
                    value = list.map { dfs($0) }
                }
                return CBORTag(tag: Int(tag.rawValue), value: value)
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
            } else if let list = obj as? IndefiniteList<Any> {
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

        return try dfs(RawPlutusData.toPrimitive(self)) as! [String: Any]
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
    class func fromDict(_ data: [String: Any]) throws -> RawPlutusData {
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
                        return CBORTag(tag: tag, value: convertedFields)
                    } else {
                        return CBORTag(tag: 102, value: [constructor, IndefiniteList(convertedFields)])
                    }
                } else if let map = dict["map"] as? [[String: Any]] {
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
                    return IndefiniteList(try list.map { try dfs($0) })
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
              let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw NSError(domain: "RawPlutusData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        return try fromDict(dict)
    }
}
