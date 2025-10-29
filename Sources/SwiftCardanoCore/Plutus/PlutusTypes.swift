import Foundation
import PotentCBOR

// MARK: - PlutusScript
public protocol PlutusScriptable: Serializable {
    var data: Data { get set }
    var version: Int { get }
    func getScriptHashPrefix() -> Data
}

public enum PlutusScript: Serializable {
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
    
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
    
    public static func fromVersion(_ version: Int, data: Data) -> PlutusScript {
        switch version {
            case 1:
                return .plutusV1Script(PlutusV1Script(data: data))
            case 2:
                return .plutusV2Script(PlutusV2Script(data: data))
            case 3:
                return .plutusV3Script(PlutusV3Script(data: data))
            default:
                fatalError("Invalid PlutusScript version: \(version)")
        }
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .uint(version) = elements[0],
              case let .bytes(data) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid PlutusScript primitive")
        }
        
        self = Self.fromVersion(Int(version), data: data)
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
                  case let .uint(version) = elements[0],
                  case let .bytes(data) = elements[1] else {
                throw CardanoCoreError.deserializeError("Invalid PlutusScript list dictionary")
            }
            return Self.fromVersion(Int(version), data: data)
            
        case .orderedDict(let dict):
            guard let typeValue = dict[.string("type")],
                  case .string(let typeStr) = typeValue,
                  let dataValue = dict[.string("data")],
                  case .string(let base64String) = dataValue,
                  let data = Data(base64Encoded: base64String) else {
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
            
            return Self.fromVersion(version, data: data)
            
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

public struct PlutusV1Script: PlutusScriptable {
    public var data: Data
    public var version: Int = 1
    
    public init(data: Data) {
        self.data = data
    }

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
                  case .string(let base64String) = dataValue,
                  let data = Data(base64Encoded: base64String) else {
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
            .string("version"): .uint(UInt(version)),
            .string("data"): .string(data.base64EncodedString())
        ])
    }
}

public struct PlutusV2Script: PlutusScriptable {
    public var data: Data
    public var version: Int = 2
    
    public init(data: Data) {
        self.data = data
    }

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
                  case .string(let base64String) = dataValue,
                  let data = Data(base64Encoded: base64String) else {
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
            .string("version"): .uint(UInt(version)),
            .string("data"): .string(data.base64EncodedString())
        ])
    }
}

public struct PlutusV3Script: PlutusScriptable {
    public var data: Data
    public var version: Int = 3
    
    public init(data: Data) {
        self.data = data
    }

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
                  case .string(let base64String) = dataValue,
                  let data = Data(base64Encoded: base64String) else {
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
            .string("version"): .uint(UInt(version)),
            .string("data"): .string(data.base64EncodedString())
        ])
    }
}


// MARK: - ScriptType
public enum ScriptType: Serializable {
    
//    case bytes(Data)
    case nativeScript(NativeScript)
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
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
