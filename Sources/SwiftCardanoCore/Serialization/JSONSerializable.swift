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
        func bytesToString(_ data: Data) -> String {
            hexEncodeBytes
                ? data.map { String(format: "%02x", $0) }.joined()
                : data.base64EncodedString()
        }
        // Stable string for use as a JSON object key. Scalar primitives map
        // directly; complex ones (lists/dicts/tagged) are JSON-encoded so the
        // structure is at least readable instead of leaking `String(describing:)`.
        func keyToString(_ k: Primitive) -> String {
            switch k {
            case .string(let s):    return s
            case .bytes(let d):     return bytesToString(d)
            case .byteArray(let b): return bytesToString(Data(b))
            case .uint(let u):      return "\(u)"
            case .int(let i):       return "\(i)"
            case .bool(let b):      return "\(b)"
            case .null:             return "null"
            case .cborTag(let t):   return keyToString(t.value)
            case .unitInterval(let ui):
                return "\(ui.numerator)/\(ui.denominator)"
            default:
                if let any = try? primitiveToAny(k, hexEncodeBytes: hexEncodeBytes),
                   let data = try? JSONSerialization.data(
                       withJSONObject: any,
                       options: [.fragmentsAllowed, .withoutEscapingSlashes]),
                   let s = String(data: data, encoding: .utf8) {
                    return s
                }
                return String(describing: k)
            }
        }
        func pairsToAny(_ pairs: [(Primitive, Primitive)]) throws -> Any {
            var result: [String: Any] = [:]
            for (k, v) in pairs {
                result[keyToString(k)] = try primitiveToAny(v, hexEncodeBytes: hexEncodeBytes)
            }
            return result
        }
        switch primitive {
        case .string(let str):   return str
        case .int(let i):        return i
        case .uint(let u):       return u
        case .bool(let b):       return b
        case .float(let f):      return f
        case .decimal(let d):    return d
        case .bigInt(let n):     return n.description
        case .bigUInt(let n):    return n.description
        case .bytes(let data):   return bytesToString(data)
        case .byteArray(let b):  return bytesToString(Data(b))
        case .byteString(let bs): return bytesToString(bs.bytes)
        case .datetime(let d):
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: d)
        case .list(let arr), .frozenList(let arr):
            return try arr.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .indefiniteList(let list), .indefiniteFrozenList(let list):
            return try list.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .orderedSet(let s):
            return try s.elements.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .nonEmptyOrderedSet(let s):
            return try s.elements.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .frozenSet(let s):
            return try Array(s).map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .orderedDict(let dict):
            return try pairsToAny(dict.map { ($0.key, $0.value) })
        case .indefiniteDictionary(let dict):
            return try pairsToAny(dict.map { ($0.key, $0.value) })
        case .dict(let dict):
            return try pairsToAny(dict.map { ($0.key, $0.value) })
        case .frozenDict(let dict):
            return try pairsToAny(dict.map { ($0.key, $0.value) })
        case .cborTag(let tag):
            // Tag 30 = rational [num, denom]; render as a structured numerator/
            // denominator object to match `.unitInterval`.
            if tag.tag == 30, case .list(let elems) = tag.value, elems.count == 2,
               let n = elems[0].intValue, let d = elems[1].intValue {
                return [
                    "numerator":   n,
                    "denominator": d,
                ] as [String: Any]
            }
            // Otherwise drop the tag wrapper for display; the inner value is what matters.
            return try primitiveToAny(tag.value, hexEncodeBytes: hexEncodeBytes)
        case .unitInterval(let ui):
            return [
                "numerator":   ui.numerator,
                "denominator": ui.denominator,
            ] as [String: Any]
        case .null: return NSNull()
        default: return String(describing: primitive)
        }
    }

}
