import Foundation
import CryptoKit
import SwiftNcal

/// A class that holds a cryptographic key and some metadata. e.g. signing key, verification key.
class Key: CBORSerializable, Hashable, Equatable {

    class var KEY_TYPE: String { return "" }
    class var DESCRIPTION: String { return "" }
    
    public var payload: Data { get { return _payload } }
    private let _payload: Data
    
    public var keyType: String { get { return _keyType } }
    private let _keyType: String
    
    public var keyDescription: String { get { return _description } }
    private let _description: String
    
    required init(payload: Data, keyType: String? = nil, description: String? = nil) {
        self._payload = payload
        self._keyType = keyType ?? Self.KEY_TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    func toShallowPrimitive() -> Any {
        return payload
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        return self.init(payload: value as! Data) as! T
    }
    
    /// Serialize the key to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation of the key.
    func toJSON() throws -> String? {
        let cborHex = try toCBORHex()!
        let jsonString = """
        {
            "type": "\(keyType)",
            "description": "\(keyDescription)",
            "cborHex": "\(cborHex)"
        }
        """
        return jsonString
    }
    
    class func fromDict(_ dict: Dictionary<String, String>, validateType: Bool = false) throws -> Self {
        guard let keyType = dict["type"],
              let description = dict["description"],
              let cborHex = dict["cborHex"] else {
            throw CardanoException.valueError("Invalid Dictionary")
        }
        
        if validateType {
            guard validateType, dict["type"] == KEY_TYPE else {
                throw CardanoException.invalidKeyTypeException("Expect key type: \(KEY_TYPE), but got \(dict["type"] ?? "")")
            }
        }
        
        let cborData = Data(hexString: cborHex)!
        let key = try fromCBOR(cborData)
        
        return Self(
            payload: key!.payload,
            keyType: keyType,
            description: description
        )
    }
    
    /// Restore a key from a JSON string.
    /// - Parameters:
    ///   - json: JSON string.
    ///   - validateType:  Checks whether the type specified in json object is the same as the class's default type.
    /// - Returns: The key restored from JSON.
    class func fromJSON(_ json: String, validateType: Bool = false) throws -> Self {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String]else {
            throw CardanoException.valueError("Invalid JSON")
        }
        
        return try fromDict(dict, validateType: validateType)
    }
    
    func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoException.ioError("File already exists: \(path)")
        }
        
        if let jsonString = try toJSON() {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    static func load(from path: String) throws -> Self {
        let jsonString = try String(contentsOfFile: path)
        return try fromJSON(jsonString)
    }
    
//    func toCBOR() -> Data {
//        return payload
//    }
    
    // Convert to raw bytes
    func toBytes() -> Data {
        return payload
    }
    
    // Equality check
    static func == (lhs: Key, rhs: Key) -> Bool {
        return lhs.payload == rhs.payload &&
               lhs.keyDescription == rhs.keyDescription &&
               lhs.keyType == rhs.keyType
    }
    
    // String representation
    func description() throws -> String {
        return try toJSON() ?? "Invalid JSON representation"
    }
    
    // Hash function
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}
