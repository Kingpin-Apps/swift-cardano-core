import Foundation

public protocol Serializable: CBORSerializable, JSONSerializable, Sendable  {}

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
