import Foundation

protocol JSONSerializable: Codable, Hashable, Equatable {
    func toJSON() throws -> String?
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> Self
}

extension JSONSerializable {
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
        if let data = json.data(using: .utf8) {
            do {
                let dict = try JSONSerialization.jsonObject(with: data) as! [AnyHashable: Any]
                return try fromDict(dict)
            } catch {
                throw CardanoCoreError.valueError("Error: \(error)")
            }
        } else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
    }
}
