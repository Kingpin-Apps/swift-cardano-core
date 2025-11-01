import Foundation
import PotentCBOR

public protocol TextEnvelopable: PayloadSerializable {}

public extension TextEnvelopable {
    /// Serialize to TextEnvelople JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: TextEnvelople JSON representation
    func toTextEnvelope() throws -> String? {
        let jsonString = """
        {
            "type": "\(_type)",
            "description": "\(_description)",
            "cborHex": "\(_payload.toHex)"
        }
        """
        return jsonString
    }
    
    /// Restore from a JSON string.
    /// - Parameters:
    ///   - json: JSON string.
    ///   - validateType: Checks whether the type specified in json object is the same as the class's default type.
    /// - Returns: The object restored from JSON.
    static func fromTextEnvelope(_ json: String, validateType: Bool = false) throws -> Self {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
        
        guard let type = dict["type"],
              let description = dict["description"],
              let cborHex = dict["cborHex"] else {
            throw CardanoCoreError.valueError("Invalid Dictionary")
        }
        
        if validateType {
            guard validateType, dict["type"] == Self.TYPE else {
                throw CardanoCoreError.invalidKeyTypeError("Expect key type: \(Self.TYPE), but got \(dict["type"] ?? "")")
            }
        }
        
        var obj = try Self.fromCBORHex(cborHex)
        obj._type = type
        obj._description = description
        
        return obj
    }
    
    /// Save the JSON representation to a file.
    /// - Parameter path: The file path.
    func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        if let jsonString = try toTextEnvelope() {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    static func load(from path: String) throws -> Self {
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        return try fromTextEnvelope(jsonString)
    }
}
