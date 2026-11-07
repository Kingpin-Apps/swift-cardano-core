import Foundation
import OrderedCollections

/// A value that can describe itself as JSON.
///
/// The protocol's extension uses the JSON for ``description`` and
/// ``debugDescription``, pretty-printed with sorted keys.
public protocol JSONDescribable: Codable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Returns the value as a JSON string.
    /// - Returns: The JSON text, or `nil` when it cannot be produced as UTF-8.
    func toJSON() throws -> String?
    /// Returns a JSON string used for display (e.g. `description`). Defaults to `toJSON()`.
    func toDisplayJSON() throws -> String?
}

extension JSONDescribable {
    /// The value's display JSON, pretty-printed with sorted keys.
    ///
    /// `{}` when there is no JSON to show, or an error message when producing
    /// it throws.
    public var debugDescription: String {
        do {
            guard let json = try self.toDisplayJSON() else { return "{}" }

            guard let data = json.data(using: .utf8) else { return "{}" }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
                return "{}"
            }

            guard
                let prettyData = try? JSONSerialization.data(
                    withJSONObject: jsonObject,
                    options: [
                        .prettyPrinted,
                        .sortedKeys,
                        .withoutEscapingSlashes,
                        .fragmentsAllowed,
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

    /// The same text as ``debugDescription``.
    public var description: String { self.debugDescription }

    /// Default implementation: delegates to `toJSON()`.
    public func toDisplayJSON() throws -> String? { try toJSON() }
}

/// A value that reads from and writes to JSON through a ``Primitive``
/// dictionary form.
///
/// A conforming type converts itself to and from the primitive that mirrors
/// its JSON; the protocol's extension turns that into JSON text and back.
public protocol JSONSerializable: JSONDescribable, Hashable, Equatable {
    /// Creates a value from the primitive form of its JSON.
    /// - Parameter primitive: The JSON as a primitive, as ``fromJSON(_:)``
    ///   builds it: objects as `.orderedDict` with string keys, non-negative
    ///   integers as `.uint`.
    /// - Returns: The value the primitive describes.
    /// - Throws: `CardanoCoreError` when the primitive does not have the
    ///   shape this type expects.
    static func fromDict(_ primitive: Primitive) throws -> Self
    /// Returns the value as the primitive form of its JSON.
    /// - Returns: A primitive that ``JSONDescribable/toJSON()`` writes as JSON.
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
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            let primitive = try JSONPrimitiveReader.read(jsonObject)
            return try fromDict(primitive)
        } catch let error as CardanoCoreError {
            throw error
        } catch {
            throw CardanoCoreError.valueError("Error parsing JSON: \(error)")
        }
    }

    /// The JSON form of the value, binary fields as hex strings, as
    /// cardano-cli writes them. ``fromJSON(_:)`` reads it back as an equal
    /// value, but not the bytes the value was read from: to keep those — a
    /// transaction's id and signatures depend on them — use CBOR. A value
    /// whose dict form is a single string or number, a hash say, is written as
    /// that bare JSON value.
    public func toJSON() throws -> String? {
        let primitive = try self.toDict()
        let jsonObject = try Self.primitiveToAny(primitive, hexEncodeBytes: true)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        )
        return String(data: jsonData, encoding: .utf8)
    }

    /// Returns a JSON string with binary `Data` fields encoded as lowercase hex strings.
    public func toDisplayJSON() throws -> String? {
        let primitive = try self.toDict()
        let jsonObject = try Self.primitiveToAny(primitive, hexEncodeBytes: true)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
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
            return try s.elementsOrdered.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
        case .nonEmptyOrderedSet(let s):
            return try s.elementsOrdered.map { try primitiveToAny($0, hexEncodeBytes: hexEncodeBytes) }
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

/// Converts a `JSONSerialization` value to the primitive
/// ``JSONSerializable/fromDict(_:)`` reads: objects as `.orderedDict` with
/// their keys sorted, non-negative integers as `.uint`.
///
/// It works in a loop rather than recursing, so JSON nested as deeply as the
/// parser accepts cannot exhaust a small thread stack. A conforming type whose
/// `fromDict(_:)` recurses bounds the depth it reads.
enum JSONPrimitiveReader {
    /// A container being filled: its children, the next one to convert and
    /// those already converted.
    private enum Frame {
        case list(items: [Any], next: Int, built: [Primitive])
        case object(keys: [String], values: [String: Any], next: Int,
                    built: OrderedDictionary<Primitive, Primitive>)
    }

    /// The primitive for a JSON value.
    ///
    /// - Throws: When the value holds a type JSON does not have.
    static func read(_ root: Any) throws -> Primitive {
        var stack: [Frame] = []
        var current = root
        while true {
            let produced: Primitive
            if let items = current as? [Any] {
                if let first = items.first {
                    stack.append(.list(items: items, next: 1, built: []))
                    current = first
                    continue
                }
                produced = .list([])
            } else if let values = current as? [String: Any] {
                // Sort keys to ensure deterministic ordering when loading from JSON
                let keys = values.keys.sorted()
                if let first = keys.first {
                    stack.append(.object(keys: keys, values: values, next: 1, built: [:]))
                    current = values[first]!
                    continue
                }
                produced = .orderedDict([:])
            } else {
                produced = try scalar(current)
            }
            if let result = finish(produced, &stack, &current) { return result }
        }
    }

    /// Hands `value` to the containers above it, closing each one it
    /// completes. Returns the root once it is complete; otherwise sets
    /// `current` to the next child to convert and returns `nil`.
    private static func finish(_ value: Primitive, _ stack: inout [Frame], _ current: inout Any) -> Primitive? {
        var value = value
        while let frame = stack.popLast() {
            switch frame {
            case .list(let items, let next, var built):
                built.append(value)
                if next < items.count {
                    stack.append(.list(items: items, next: next + 1, built: built))
                    current = items[next]
                    return nil
                }
                value = .list(built)
            case .object(let keys, let values, let next, var built):
                built[.string(keys[next - 1])] = value
                if next < keys.count {
                    stack.append(.object(keys: keys, values: values, next: next + 1, built: built))
                    current = values[keys[next]]!
                    return nil
                }
                value = .orderedDict(built)
            }
        }
        return value
    }

    /// A JSON value that is not an array or an object, as a primitive.
    private static func scalar(_ value: Any) throws -> Primitive {
        // JSONSerialization gives every number and boolean as an
        // NSNumber, which casts to Int as readily as to Bool: ask
        // which it is before casting. `objCType` is "c" for a
        // boolean on Darwin and on swift-corelibs-foundation alike.
        if let number = value as? NSNumber, String(cString: number.objCType) == "c" {
            return .bool(number.boolValue)
        }
        switch value {
        case let str as String: return .string(str)
        // A non-negative integer is read as CBOR reads one, as .uint.
        case let i as Int: return i < 0 ? .int(Int64(i)) : .uint(UInt64(i))
        case let u as UInt: return .uint(UInt64(u))
        case let f as Double: return .float(f)
        case let f as Float: return .float(Double(f))
        case is NSNull: return .null
        default:
            throw CardanoCoreError.valueError("Unsupported JSON type: \(type(of: value))")
        }
    }
}

/// The deepest value the recursive JSON readers read, counting the outermost
/// value as level 1: ``PlutusData/maxConversionDepth``, the depth the
/// conversions to JSON allow, which fits a 512 KB thread stack.
let maxJSONDecodeDepth = 128

/// Throws when `level` is past `limit`.
///
/// - Parameters:
///   - level: The depth of the value being read; the outermost is level 1.
///   - limit: The deepest level allowed.
///   - what: What is being read, for the error message.
/// - Throws: `CardanoCoreError.deserializeError` when `level` is past `limit`.
func checkJSONDepth(_ level: Int, limit: Int = maxJSONDecodeDepth, _ what: @autoclosure () -> String) throws {
    guard level <= limit else {
        throw CardanoCoreError.deserializeError(
            "\(what()) nests deeper than \(limit) levels, too deep to read")
    }
}

extension Primitive {
    /// The bytes of a field read from JSON: raw bytes, or a string of hex —
    /// what ``JSONDescribable/toJSON()`` writes — or of base64, which earlier
    /// versions wrote. Hex is tried
    /// first, and either reading must give `count` bytes when it is set, so a
    /// hex string that also happens to be valid base64 is not misread.
    func jsonBytes(_ field: String, count: Int? = nil) throws -> Data {
        func fits(_ data: Data) -> Bool { count.map { data.count == $0 } ?? true }
        switch self {
        case .bytes(let data) where fits(data):
            return data
        case .string(let string):
            if let data = Data(hexString: string), fits(data) { return data }
            if let data = Data(base64Encoded: string), fits(data) { return data }
        default:
            break
        }
        let size = count.map { "\($0) bytes of " } ?? ""
        throw CardanoCoreError.deserializeError("\(field) must be \(size)hex or base64, got \(self)")
    }
}
