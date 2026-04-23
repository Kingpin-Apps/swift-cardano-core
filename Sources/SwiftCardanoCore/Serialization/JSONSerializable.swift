import Foundation
import OrderedCollections
import PotentCodables

public protocol JSONDescribable: Codable, CustomStringConvertible, CustomDebugStringConvertible {
    func toJSON() throws -> String?
    /// Returns a JSON string used for display (e.g. `description`). Defaults to `toJSON()`.
    func toDisplayJSON() throws -> String?
}

extension JSONDescribable {
    public var debugDescription: String {
        do {
            guard let json = try self.toDisplayJSON() else { return "{}" }

            guard let data = json.data(using: .utf8) else { return "{}" }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
                return "{}"
            }

            guard
                let prettyData = try? JSONSerialization.data(
                    withJSONObject: jsonObject,
                    options: [
                        .prettyPrinted,
                        .sortedKeys,
                        .withoutEscapingSlashes,
                    ]
                )
            else {
                return "{}"
            }

            return String(data: prettyData, encoding: .utf8) ?? "{}"
        } catch {
            return "Error generating JSON description for \(Self.self): \(error)"
        }
    }

    public var description: String { self.debugDescription }

    /// Default implementation: delegates to `toJSON()` (base64 encoding for Data).
    public func toDisplayJSON() throws -> String? { try toJSON() }
}

public protocol JSONSerializable: JSONDescribable, Hashable, Equatable {
    static func fromDict(_ primitive: Primitive) throws -> Self
    func toDict() throws -> Primitive
}

extension JSONSerializable {

    /// Restore from a JSON string.
    /// - Parameters:
    ///   - json: JSON string.
    /// - Returns: The object restored from JSON.
    public static func fromJSON(_ json: String) throws -> Self {
        guard let data = json.data(using: .utf8) else {
            throw CardanoCoreError.valueError("Invalid JSON: cannot convert to UTF-8")
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            // Convert Any to Primitive
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
                    // Sort keys to ensure deterministic ordering when loading from JSON
                    for k in dict.keys.sorted() {
                        result[.string(k)] = try anyToPrimitive(dict[k]!)
                    }
                    return .orderedDict(result)
                case is NSNull: return .null
                default:
                    throw CardanoCoreError.valueError("Unsupported JSON type: \(type(of: value))")
                }
            }

            let primitive = try anyToPrimitive(jsonObject)
            return try fromDict(primitive)
        } catch let error as CardanoCoreError {
            throw error
        } catch {
            throw CardanoCoreError.valueError("Error parsing JSON: \(error)")
        }
    }

    public func toJSON() throws -> String? {
        let primitive = try self.toDict()
        let jsonObject = try Self.primitiveToAny(primitive, hexEncodeBytes: false)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return String(data: jsonData, encoding: .utf8)
    }

    /// Returns a JSON string with binary `Data` fields encoded as lowercase hex strings.
    public func toDisplayJSON() throws -> String? {
        let primitive = try self.toDict()
        let jsonObject = try Self.primitiveToAny(primitive, hexEncodeBytes: true)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return String(data: jsonData, encoding: .utf8)
    }

    private static func primitiveToAny(_ primitive: Primitive, hexEncodeBytes: Bool) throws -> Any {
        switch primitive {
        case .string(let str): return str
        case .int(let i): return i
        case .uint(let u): return u
        case .bool(let b): return b
        case .float(let f): return f
        case .bytes(let data):
            if hexEncodeBytes {
                return data.map { String(format: "%02x", $0) }.joined()
            } else {
                return data.base64EncodedString()
            }
        case .list(let arr):
            return try arr.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .orderedDict(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict {
                let keyStr: String
                if case .string(let s) = k {
                    keyStr = s
                } else {
                    keyStr = String(describing: k)
                }
                result[keyStr] = try primitiveToAny(v, hexEncodeBytes: hexEncodeBytes)
            }
            return result
        case .null: return NSNull()
        default: return String(describing: primitive)
        }
    }

}
