import Foundation
import OrderedCollections

public protocol Serializable: CBORSerializable, JSONSerializable, Sendable  {}

/// Default `JSONSerializable` implementation for any `CBORSerializable` type.
/// Conforming to `Serializable` is sufficient — `toDict()` and `fromDict()` are
/// provided here so types don't need to implement them separately.
public extension JSONSerializable where Self: CBORSerializable {
    static func fromDict(_ primitive: Primitive) throws -> Self {
        try Self.init(from: primitive)
    }
    
    func toDict() throws -> Primitive {
        do {
            let mirror = Mirror(reflecting: self)
            var dict = OrderedDictionary<Primitive, Primitive>()
            for child in mirror.children {
                guard let label = child.label else { continue }

                switch child.value {
                    case let v as any Serializable:
                        dict[.string(label)] = try v.toDict()
                    case let v as any CBORSerializable:
                        dict[.string(label)] = try v.toPrimitive()
                    default:
                        dict[.string(label)] = try Primitive.fromAny(child.value)
                }
            }
            return .orderedDict(dict)
        } catch {
            // Mirror-based traversal can't represent fields that don't conform to
            // CBORSerializable (e.g. Swift tuples). Fall back to the type's own
            // CBOR encoding, which is always representable as a Primitive.
            return try toPrimitive()
        }
    }
}

public extension Serializable {
    init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let json = try container.decode(String.self)
            self = try Self.fromJSON(json)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
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
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        return try fromJSON(jsonString)
    }
}
