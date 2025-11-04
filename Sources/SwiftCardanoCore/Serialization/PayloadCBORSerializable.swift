import Foundation
import PotentCBOR

public protocol PayloadCBORSerializable: PayloadSerializable {}

public extension PayloadCBORSerializable where Self: Codable {
    
    /// Deserialize from CBOR.
    /// - Parameter decoder: The decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        try self.init(payload: payload)
    }
    
    /// Serialize to CBOR.
    /// - Parameter encoder: The encoder.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }
    
    func toPrimitive() -> Primitive {
        return .bytes(payload)
    }
    
    init(from primitive: Primitive) throws {
        guard case let .bytes(payload) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid payload for \(Self.self): expected bytes but got \(primitive) type")
        }
        try self.init(payload: payload)
    }
    
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation of the object.   
    func toJSON() throws -> String? {
        return try self.toTextEnvelope()
    }
    
    func toTextEnvelope() throws -> String? {
        let cborData = try CBOREncoder().encode(payload)
        let jsonString = """
        {
            "type": "\(type)",
            "description": "\(description)",
            "cborHex": "\(cborData.toHex)"
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
        
        return try Self.fromDict(dict, validateType: validateType)
    }
    
    /// Save the JSON representation to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and overwrite is false.
    func save(to path: String, overwrite: Bool = false) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
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
    
    /// Restore from a dictionary.
    /// - Parameters:
    ///   - dict: The dictionary representation of the object
    ///   - validateType: Whether to validate the type of the object
    /// - Returns: The object restored from the dictionary
    static func fromDict(_ dict: Dictionary<String, String>, validateType: Bool = false) throws -> Self {
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
}
