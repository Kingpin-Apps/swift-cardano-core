import Foundation
import OrderedCollections
import PotentCodables

public protocol JSONDescribable: Codable, CustomStringConvertible, CustomDebugStringConvertible {
    func toJSON() throws -> String?
}

public extension JSONDescribable {
    var description: String {
        do {
            let json = try self.toJSON()
            
            guard let data = json?.data(using: .utf8) else {
                return "{}"
            }
            
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
                return "{}"
            }
            
            guard let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes
                ]
            ) else {
                return "{}"
            }
            
            return String(data: prettyData, encoding: .utf8) ?? "{}"
        } catch {
            return "Error generating JSON description: \(error)"
        }
    }
    
    var debugDescription: String { self.description }
}

public protocol JSONSerializable: JSONDescribable, Hashable, Equatable {
    func toDict() throws -> OrderedDictionary<Primitive, Primitive>
    static func fromDict(_ dict: OrderedDictionary<Primitive, Primitive>) throws -> Self
}

public extension JSONSerializable {
    /// Save the JSON representation to a file.
    /// - Parameter path: The file path.
    func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        if let jsonString = try toJSON() {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    static func load(from path: String) throws -> Self {
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        return try fromJSON(jsonString)
    }
    
    /// Restore from a JSON string.
    /// - Parameters:
    ///   - json: JSON string.
    /// - Returns: The object restored from JSON.
    static func fromJSON(_ json: String) throws -> Self {
        guard let data = json.data(using: .utf8) else {
            throw CardanoCoreError.valueError("Invalid JSON: cannot convert to UTF-8")
        }
        
        do {
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CardanoCoreError.valueError("Invalid JSON: expected object")
            }
            
            // Convert [String: Any] to OrderedDictionary<Primitive, Primitive>
            func anyToPrimitive(_ value: Any) throws -> Primitive {
                switch value {
                case let str as String: return .string(str)
                case let i as Int: return .int(i)
                case let u as UInt: return .uint(u)
                case let b as Bool: return .bool(b)
                case let f as Double: return .float(f)
                case let f as Float: return .float(Double(f))
                case let arr as [Any]: return .list(try arr.map { try anyToPrimitive($0) })
                case let dict as [String: Any]:
                    var result: OrderedDictionary<Primitive, Primitive> = [:]
                    for (k, v) in dict {
                        result[.string(k)] = try anyToPrimitive(v)
                    }
                    return .orderedDict(result)
                case is NSNull: return .null
                default: throw CardanoCoreError.valueError("Unsupported JSON type: \(type(of: value))")
                }
            }
            
            var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
            for (key, value) in jsonDict {
                primitiveDict[.string(key)] = try anyToPrimitive(value)
            }
            
            return try fromDict(primitiveDict)
        } catch let error as CardanoCoreError {
            throw error
        } catch {
            throw CardanoCoreError.valueError("Error parsing JSON: \(error)")
        }
    }
    
    func toJSON() throws -> String? {
        let dict = try self.toDict()
        
        // Convert OrderedDictionary<Primitive, Primitive> to [String: Any] for JSONSerialization
        func primitiveToAny(_ primitive: Primitive) throws -> Any {
            switch primitive {
            case .string(let str): return str
            case .int(let i): return i
            case .uint(let u): return u
            case .bool(let b): return b
            case .float(let f): return f
            case .bytes(let data): return data.base64EncodedString()
            case .list(let arr): return try arr.map { try primitiveToAny($0) }
            case .orderedDict(let dict):
                var result: [String: Any] = [:]
                for (k, v) in dict {
                    guard case let .string(keyStr) = k else {
                        throw CardanoCoreError.valueError("JSON object keys must be strings")
                    }
                    result[keyStr] = try primitiveToAny(v)
                }
                return result
            case .null: return NSNull()
            default: return String(describing: primitive)
            }
        }
        
        var jsonDict: [String: Any] = [:]
        for (key, value) in dict {
            guard case let .string(keyStr) = key else {
                throw CardanoCoreError.valueError("JSON object keys must be strings")
            }
            jsonDict[keyStr] = try primitiveToAny(value)
        }
        
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonDict,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return String(data: jsonData, encoding: .utf8)
    }
    
}
