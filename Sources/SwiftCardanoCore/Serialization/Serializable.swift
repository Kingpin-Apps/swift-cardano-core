import Foundation
import OrderedCollections

public protocol Serializable: CBORSerializable, JSONSerializable, Sendable  {}

/// Default `JSONSerializable` implementation for any `CBORSerializable` type.
/// Conforming to `Serializable` is sufficient — `toDict()` and `fromDict()` are
/// provided here so types don't need to implement them separately.
///
/// The default JSON is the value's own CBOR shape when JSON carries that
/// shape without loss — integers, text, booleans, null, lists and maps keyed
/// by text — and otherwise the hex of its CBOR. Either reads back as the same
/// value. A type with a more readable JSON form implements its own pair.
public extension JSONSerializable where Self: CBORSerializable {
    static func fromDict(_ primitive: Primitive) throws -> Self {
        if case .string(let hex) = primitive, let data = Data(hexString: hex),
           let value = try? Self.fromCBOR(data: data) {
            return value
        }
        return try Self.init(from: primitive)
    }

    func toDict() throws -> Primitive {
        let primitive = try toPrimitive()
        return primitive.survivesJSON ? primitive : .string(try toCBORHex())
    }
}

extension Primitive {
    /// Whether JSON carries this value without loss: it reads back as the
    /// same primitive. Bytes, tags, floats and maps keyed by anything but
    /// text do not survive.
    var survivesJSON: Bool {
        var pending = [self]
        while let value = pending.popLast() {
            switch value {
            case .uint, .string, .bool, .null:
                continue
            case .int(let int) where int < 0:
                continue
            case .list(let elements):
                pending.append(contentsOf: elements)
            case .orderedDict(let dict):
                for (key, element) in dict {
                    guard case .string = key else { return false }
                    pending.append(element)
                }
            default:
                return false
            }
        }
        return true
    }
}

public extension Serializable {
    init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let json = try container.decode(String.self)
            self = try Self.fromJSON(json)
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: Self.preservesEncoding)
            try self.init(from: primitive)
        }
    }
    
    
    func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            let json = try self.toJSON()
            try container.encode(json)
        } else  {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }
    
    /// Save the JSON representation to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and overwrite is false.  
    func saveJSON(to path: String, overwrite: Bool = false) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        if let jsonString = try toJSON() {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    static func loadJSON(from path: String) throws -> Self {
        let jsonString = try readTextFile(path)
        return try fromJSON(jsonString)
    }
}
