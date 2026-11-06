import Foundation
import CBORCodable

// MARK: - PlutusScript
/// A Plutus script of one language version.
public protocol PlutusScriptable: Serializable {
    /// The script bytes.
    var data: Data { get set }
    /// The Plutus language version: 1, 2 or 3.
    var version: Int { get }
    /// The byte put before the script bytes when hashing the script. It identifies the language version.
    ///
    /// - Returns: The one-byte prefix.
    func getScriptHashPrefix() -> Data
}

/// A Plutus script of any language version.
///
/// In CBOR it is `[version, script_bytes]`, where `version` is 1, 2 or 3.
public enum PlutusScript: Serializable {
    /// A Plutus V1 script, written with version `1`.
    case plutusV1Script(PlutusV1Script)
    /// A Plutus V2 script, written with version `2`.
    case plutusV2Script(PlutusV2Script)
    /// A Plutus V3 script, written with version `3`.
    case plutusV3Script(PlutusV3Script)
    
    /// The same script as a ``ScriptType``.
    public var toScriptType: ScriptType {
        switch self {
            case .plutusV1Script(let data):
                return .plutusV1Script(data)
            case .plutusV2Script(let data):
                return .plutusV2Script(data)
            case .plutusV3Script(let data):
                return .plutusV3Script(data)
        }
    }
    
    /// - Throws: When `version` is not 1, 2 or 3.
    public static func fromVersion(_ version: Int, data: Data) throws -> PlutusScript {
        switch version {
            case 1:
                return .plutusV1Script(PlutusV1Script(data: data))
            case 2:
                return .plutusV2Script(PlutusV2Script(data: data))
            case 3:
                return .plutusV3Script(PlutusV3Script(data: data))
            default:
                throw CardanoCoreError.deserializeError("Invalid PlutusScript version: \(version)")
        }
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let elements = primitive.arrayElements,
              elements.count == 2,
              case let .bytes(data) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid PlutusScript primitive")
        }
        let version = try elements[0].integer("PlutusScript version", as: Int.self)
        
        self = try Self.fromVersion(version, data: data)
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .plutusV1Script(let script):
            return .list([.uint(1), .bytes(script.data)])
        case .plutusV2Script(let script):
            return .list([.uint(2), .bytes(script.data)])
        case .plutusV3Script(let script):
            return .list([.uint(3), .bytes(script.data)])
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> PlutusScript {
        // Support both formats: list or dictionary
        switch primitive {
        case .list(let elements):
            guard elements.count == 2,
                  case let .bytes(data) = elements[1] else {
                throw CardanoCoreError.deserializeError("Invalid PlutusScript list dictionary")
            }
            let version = try elements[0].integer("PlutusScript version", as: Int.self)
            return try Self.fromVersion(version, data: data)
            
        case .orderedDict(let dict):
            guard let typeValue = dict[.string("type")],
                  case .string(let typeStr) = typeValue,
                  let dataValue = dict[.string("data")],
                  let data = try? dataValue.jsonBytes("Plutus script data") else {
                throw CardanoCoreError.deserializeError("Invalid PlutusScript dictionary: missing or invalid fields")
            }
            
            let version: Int
            switch typeStr {
            case "PlutusV1Script": version = 1
            case "PlutusV2Script": version = 2
            case "PlutusV3Script": version = 3
            default:
                throw CardanoCoreError.deserializeError("Unknown PlutusScript type: \(typeStr)")
            }
            
            return try Self.fromVersion(version, data: data)
            
        default:
            throw CardanoCoreError.deserializeError("Invalid PlutusScript dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        switch self {
        case .plutusV1Script(let script):
            return try script.toDict()
        case .plutusV2Script(let script):
            return try script.toDict()
        case .plutusV3Script(let script):
            return try script.toDict()
        }
    }
}

/// A Plutus V1 script.
///
/// In CBOR it is a byte string holding the script bytes. Its script hash is taken over the prefix byte `0x01` followed by those bytes.
public struct PlutusV1Script: PlutusScriptable {
    /// The script bytes.
    public var data: Data
    /// The Plutus language version, 1.
    public var version: Int = 1
    
    /// Creates a Plutus V1 script.
    ///
    /// - Parameter data: The script bytes.
    public init(data: Data) {
        self.data = data
    }

    /// The byte put before the script bytes when hashing the script, `0x01`.
    ///
    /// - Returns: The one-byte prefix.
    public func getScriptHashPrefix() -> Data {
        Data([0x01])
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV1Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> PlutusV1Script {
        // Support both formats: direct bytes or dictionary with "data" key
        switch primitive {
        case .bytes(let data):
            return PlutusV1Script(data: data)
        case .orderedDict(let dict):
            guard let dataValue = dict[.string("data")],
                  let data = try? dataValue.jsonBytes("Plutus script data") else {
                throw CardanoCoreError.deserializeError("Invalid PlutusV1Script dictionary: missing or invalid 'data' field")
            }
            return PlutusV1Script(data: data)
        default:
            throw CardanoCoreError.deserializeError("Invalid PlutusV1Script dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        return .orderedDict([
            .string("type"): .string("PlutusV1Script"),
            .string("version"): .integer(version),
            .string("data"): .string(data.toHex)
        ])
    }
}

/// A Plutus V2 script.
///
/// In CBOR it is a byte string holding the script bytes. Its script hash is taken over the prefix byte `0x02` followed by those bytes.
public struct PlutusV2Script: PlutusScriptable {
    /// The script bytes.
    public var data: Data
    /// The Plutus language version, 2.
    public var version: Int = 2
    
    /// Creates a Plutus V2 script.
    ///
    /// - Parameter data: The script bytes.
    public init(data: Data) {
        self.data = data
    }

    /// The byte put before the script bytes when hashing the script, `0x02`.
    ///
    /// - Returns: The one-byte prefix.
    public func getScriptHashPrefix() -> Data {
        Data([0x02])
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV2Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> PlutusV2Script {
        // Support both formats: direct bytes or dictionary with "data" key
        switch primitive {
        case .bytes(let data):
            return PlutusV2Script(data: data)
        case .orderedDict(let dict):
            guard let dataValue = dict[.string("data")],
                  let data = try? dataValue.jsonBytes("Plutus script data") else {
                throw CardanoCoreError.deserializeError("Invalid PlutusV2Script dictionary: missing or invalid 'data' field")
            }
            return PlutusV2Script(data: data)
        default:
            throw CardanoCoreError.deserializeError("Invalid PlutusV2Script dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        return .orderedDict([
            .string("type"): .string("PlutusV2Script"),
            .string("version"): .integer(version),
            .string("data"): .string(data.toHex)
        ])
    }
}

/// A Plutus V3 script.
///
/// In CBOR it is a byte string holding the script bytes. Its script hash is taken over the prefix byte `0x03` followed by those bytes.
public struct PlutusV3Script: PlutusScriptable {
    /// The script bytes.
    public var data: Data
    /// The Plutus language version, 3.
    public var version: Int = 3
    
    /// Creates a Plutus V3 script.
    ///
    /// - Parameter data: The script bytes.
    public init(data: Data) {
        self.data = data
    }

    /// The byte put before the script bytes when hashing the script, `0x03`.
    ///
    /// - Returns: The one-byte prefix.
    public func getScriptHashPrefix() -> Data {
        Data([0x03])
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV3Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> PlutusV3Script {
        // Support both formats: direct bytes or dictionary with "data" key
        switch primitive {
        case .bytes(let data):
            return PlutusV3Script(data: data)
        case .orderedDict(let dict):
            guard let dataValue = dict[.string("data")],
                  let data = try? dataValue.jsonBytes("Plutus script data") else {
                throw CardanoCoreError.deserializeError("Invalid PlutusV3Script dictionary: missing or invalid 'data' field")
            }
            return PlutusV3Script(data: data)
        default:
            throw CardanoCoreError.deserializeError("Invalid PlutusV3Script dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        return .orderedDict([
            .string("type"): .string("PlutusV3Script"),
            .string("version"): .integer(version),
            .string("data"): .string(data.toHex)
        ])
    }
}


// MARK: - ScriptType
/// A script of any kind: a native script or a Plutus script.
///
/// A Plutus script is written as `[version, script_bytes]`, with `version` 1, 2 or 3. A native script is written in its own form. Reading treats an array whose first element is an unsigned integer as a Plutus script and anything else as a native script.
public enum ScriptType: Serializable {
    
//    case bytes(Data)
    /// A native script.
    case nativeScript(NativeScript)
    /// A Plutus V1 script.
    case plutusV1Script(PlutusV1Script)
    /// A Plutus V2 script.
    case plutusV2Script(PlutusV2Script)
    /// A Plutus V3 script.
    case plutusV3Script(PlutusV3Script)
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let elements = primitive.arrayElements,
              !elements.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid ScriptType primitive")
        }
        
        // Try to determine script type based on the first element or structure
        if case let .uint(version) = elements[0] {
            guard elements.count == 2,
                  case let .bytes(data) = elements[1] else {
                throw CardanoCoreError.deserializeError("Invalid ScriptType primitive structure")
            }
            
            switch version {
            case 1:
                self = .plutusV1Script(PlutusV1Script(data: data))
            case 2:
                self = .plutusV2Script(PlutusV2Script(data: data))
            case 3:
                self = .plutusV3Script(PlutusV3Script(data: data))
            default:
                throw CardanoCoreError.deserializeError("Invalid PlutusScript version: \(version)")
            }
        } else {
            // Assume it's a native script
            let nativeScript = try NativeScript(from: primitive)
            self = .nativeScript(nativeScript)
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .nativeScript(let script):
            return try script.toPrimitive()
        case .plutusV1Script(let script):
            return .list([.uint(1), .bytes(script.data)])
        case .plutusV2Script(let script):
            return .list([.uint(2), .bytes(script.data)])
        case .plutusV3Script(let script):
            return .list([.uint(3), .bytes(script.data)])
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> ScriptType {
        // Support both formats: list or dictionary
        switch primitive {
        case .list(let elements) where !elements.isEmpty:
            // Try to determine script type based on the first element
            if case let .uint(version) = elements[0] {
                guard elements.count == 2,
                      case let .bytes(data) = elements[1] else {
                    throw CardanoCoreError.deserializeError("Invalid ScriptType list dictionary structure")
                }
                
                switch version {
                case 1:
                    return .plutusV1Script(PlutusV1Script(data: data))
                case 2:
                    return .plutusV2Script(PlutusV2Script(data: data))
                case 3:
                    return .plutusV3Script(PlutusV3Script(data: data))
                default:
                    throw CardanoCoreError.deserializeError("Invalid PlutusScript version: \(version)")
                }
            } else {
                // Assume it's a native script
                let nativeScript = try NativeScript.fromDict(primitive)
                return .nativeScript(nativeScript)
            }
            
        case .orderedDict(let dict):
            guard let typeValue = dict[.string("type")],
                  case .string(let typeStr) = typeValue else {
                throw CardanoCoreError.deserializeError("Invalid ScriptType dictionary: missing 'type' field")
            }
            
            switch typeStr {
            case "PlutusV1Script":
                return .plutusV1Script(try PlutusV1Script.fromDict(primitive))
            case "PlutusV2Script":
                return .plutusV2Script(try PlutusV2Script.fromDict(primitive))
            case "PlutusV3Script":
                return .plutusV3Script(try PlutusV3Script.fromDict(primitive))
            default:
                // Try to parse as native script
                let nativeScript = try NativeScript.fromDict(primitive)
                return .nativeScript(nativeScript)
            }
            
        default:
            throw CardanoCoreError.deserializeError("Invalid ScriptType dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        switch self {
        case .nativeScript(let script):
            return try script.toDict()
        case .plutusV1Script(let script):
            return try script.toDict()
        case .plutusV2Script(let script):
            return try script.toDict()
        case .plutusV3Script(let script):
            return try script.toDict()
        }
    }
}
