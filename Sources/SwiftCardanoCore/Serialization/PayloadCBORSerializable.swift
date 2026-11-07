import Foundation
import CBORCodable

/// A ``PayloadSerializable`` value whose CBOR form is its payload as a
/// single CBOR byte string.
///
/// Its JSON form is a text envelope whose `cborHex` is that byte string.
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
    
    /// Returns the payload as a CBOR byte string.
    /// - Returns: `.bytes` holding the payload.
    func toPrimitive() -> Primitive {
        return .bytes(payload)
    }
    
    /// Creates a value from a CBOR byte string, with the default envelope
    /// type and description.
    /// - Parameter primitive: A `.bytes` primitive holding the payload.
    /// - Throws: `CardanoCoreError.deserializeError` when the primitive is
    ///   not bytes.
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
    
    /// Returns the value as text envelope JSON.
    ///
    /// The JSON has exactly three fields: `type`, `description`, and
    /// `cborHex`, the hex of the payload encoded as a CBOR byte string.
    /// `type` and `description` are escaped as JSON strings, so whatever they
    /// hold, the JSON reads back with the same three values.
    /// - Returns: The text envelope JSON.
    func toTextEnvelope() throws -> String? {
        let cborData = try CBOREncoder().encode(payload)
        return textEnvelopeJSON(type: type, description: description, cborHex: cborData.toHex)
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
    ///
    /// The envelope of a signing key holds the key itself, so the file is
    /// created owner-only (mode `0600`) and never exists with a looser mode.
    /// Without `overwrite` an existing file, or a symbolic link, at `path`
    /// is left alone; with it, the new file is written next to `path` and
    /// renamed over it.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and
    ///   overwrite is false, or when it cannot be written.
    func save(to path: String, overwrite: Bool = false) throws {
        if let jsonString = try toTextEnvelope() {
            try writeOwnerOnlyFile(Data(jsonString.utf8), to: path, overwrite: overwrite)
        }
    }
    
    /// Load the object from a JSON file.
    ///
    /// The file's `type` must be this type's own, so a signing key file is
    /// not read as a verification key, nor a payment key as a stake key. A
    /// type with no envelope type of its own, such as ``SigningKey``, reads
    /// any.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    /// - Throws: `CardanoCoreError.ioError` when the file cannot be read, and
    ///   `CardanoCoreError.invalidKeyTypeError` when it holds another type.
    static func load(from path: String) throws -> Self {
        let jsonString = try readTextFile(path)
        return try fromTextEnvelope(jsonString, validateType: !Self.TYPE.isEmpty)
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
