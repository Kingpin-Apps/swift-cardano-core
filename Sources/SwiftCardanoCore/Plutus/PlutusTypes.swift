import Foundation
import PotentCBOR

// MARK: - PlutusScript
public protocol PlutusScriptable: CBORSerializable, Equatable, Hashable {
    var data: Data { get set }
    var version: Int { get }
    func getScriptHashPrefix() -> Data
}

public enum PlutusScript: CBORSerializable, Equatable, Hashable {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV1Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
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
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV2Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
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
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PlutusV3Script primitive")
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(data)
    }
}


// MARK: - ScriptType
public enum ScriptType: CBORSerializable, Equatable, Hashable {
    
//    case bytes(Data)
    case nativeScript(NativeScript)
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
    
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
}
