import Foundation
import PotentCBOR

public protocol Payloadable {
    var _payload: Data { get set }
    var _type: String { get set }
    var _description: String { get set }
}


public extension Payloadable {
    var payload: Data { get { return _payload } }
    var type: String { get { return _type } }
    var description: String { get { return _description } }
}


public protocol PayloadSerializable: Payloadable, CBORSerializable, Hashable, Equatable {
    static var TYPE: String { get }
    static var DESCRIPTION: String { get }
    
//    init(payload: Data)
    init(payload: Data, type: String?, description: String?)
}

public protocol PayloadJSONSerializable: PayloadSerializable {}

public protocol PayloadCBORSerializable: PayloadJSONSerializable {}

public extension PayloadSerializable {
    init(payload: Data) {
        self.init(payload: payload, type: Self.TYPE, description: Self.DESCRIPTION)
    }
    
    /// Convert to raw bytes
    /// - Returns: The raw bytes
    func toBytes() -> Data {
        return payload
    }
    
    // Equality check
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload &&
               lhs.description == rhs.description && lhs.type == rhs.type
    }
    
    /// Hash the object.
    /// - Parameter hasher: The hasher.
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}

public extension PayloadJSONSerializable {
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation
    func toJSON() throws -> String? {
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
    static func fromJSON(_ json: String, validateType: Bool = false) throws -> Self {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw CardanoCoreError.valueError("Invalid JSON")
        }
        
        return try Self.fromDict(dict, validateType: validateType)
    }
    
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
        let jsonString = try String(contentsOfFile: path)
        return try fromJSON(jsonString)
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
        
        let cborData = Data(hexString: cborHex)!
        
        return Self(
            payload: cborData,
            type: type,
            description: description
        )
    }
}

public extension PayloadCBORSerializable where Self: Codable {
    
    /// Deserialize from CBOR.
    /// - Parameter decoder: The decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        self.init(
            payload: payload
        )
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
        self.init(payload: payload)
    }
}
