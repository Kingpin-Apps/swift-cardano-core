import Foundation
import CBORCodable

/// A ``PayloadSerializable`` value whose payload is its own CBOR, saved and
/// loaded as a cardano-cli text envelope.
///
/// The envelope's `cborHex` is the hex of the payload as it is, with no
/// extra byte-string wrapping.
public protocol TextEnvelopable: PayloadSerializable {
    /// Decodes the envelope's CBOR. A type whose reading depends on the era
    /// its envelope `type` names — `Tx BabbageEra`, say — reads it here.
    /// - Parameters:
    ///   - data: The CBOR bytes from the envelope's `cborHex`.
    ///   - type: The envelope's `type` field.
    /// - Returns: The decoded value.
    static func fromEnvelopeCBOR(_ data: Data, type: String) throws -> Self

    /// Returns the value as text envelope JSON, with three fields: `type`,
    /// `description`, and `cborHex`.
    ///
    /// A requirement, so that ``save(to:overwrite:)`` writes what the
    /// conforming type's own implementation returns. A type whose fields can
    /// change after it is made derives `cborHex` from them rather than from
    /// the payload it was made with.
    /// - Returns: The text envelope JSON.
    func toTextEnvelope() throws -> String?
}

public extension TextEnvelopable {
    /// Decodes the envelope's CBOR with ``CBORSerializable/fromCBOR(data:)``,
    /// ignoring `type`.
    /// - Parameters:
    ///   - data: The CBOR bytes from the envelope's `cborHex`.
    ///   - type: The envelope's `type` field.
    /// - Returns: The decoded value.
    static func fromEnvelopeCBOR(_ data: Data, type: String) throws -> Self {
        try fromCBOR(data: data)
    }

    /// Returns the value as text envelope JSON, with `cborHex` the hex of
    /// the payload.
    ///
    /// The JSON has exactly three fields: `type`, `description`, and
    /// `cborHex`, with `type` and `description` escaped as JSON strings.
    /// - Returns: The text envelope JSON.
    func toTextEnvelope() throws -> String? {
        textEnvelopeJSON(type: _type, description: _description, cborHex: _payload.toHex)
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
        
        guard let cbor = Data(hexString: cborHex) else {
            throw CardanoCoreError.invalidArgument("Invalid hex string (\(cborHex.count) characters)")
        }
        var obj = try Self.fromEnvelopeCBOR(cbor, type: type)
        obj._type = type
        obj._description = description
        
        return obj
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
        let jsonString = try readTextFile(path)
        return try fromTextEnvelope(jsonString)
    }
}

/// The text envelope JSON cardano-cli writes: `type`, `description` and
/// `cborHex` in that order, indented by four spaces.
///
/// `type` and `description` may come from a file another party wrote, so
/// they are escaped as JSON strings: a quote in either cannot end the string
/// and add a key of its own. Slashes are left as they are, as cardano-cli
/// leaves them.
func textEnvelopeJSON(type: String, description: String, cborHex: String) -> String {
    """
    {
        "type": "\(jsonEscaped(type))",
        "description": "\(jsonEscaped(description))",
        "cborHex": "\(jsonEscaped(cborHex))"
    }
    """
}

/// `string` with a backslash before every quote and backslash, and every
/// control character from U+0000 to U+001F written as a JSON escape.
func jsonEscaped(_ string: String) -> String {
    var escaped = String.UnicodeScalarView()
    for scalar in string.unicodeScalars {
        switch scalar {
            case "\"": escaped.append(contentsOf: "\\\"".unicodeScalars)
            case "\\": escaped.append(contentsOf: "\\\\".unicodeScalars)
            case "\n": escaped.append(contentsOf: "\\n".unicodeScalars)
            case "\r": escaped.append(contentsOf: "\\r".unicodeScalars)
            case "\t": escaped.append(contentsOf: "\\t".unicodeScalars)
            case "\u{08}": escaped.append(contentsOf: "\\b".unicodeScalars)
            case "\u{0C}": escaped.append(contentsOf: "\\f".unicodeScalars)
            case let control where control.value < 0x20:
                let hex = String(control.value, radix: 16)
                escaped.append(contentsOf: ("\\u" + String(repeating: "0", count: 4 - hex.count) + hex).unicodeScalars)
            default:
                escaped.append(scalar)
        }
    }
    return String(escaped)
}
