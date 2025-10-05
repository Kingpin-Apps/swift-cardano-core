import Foundation
import PotentCodables
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
              case let .int(version) = elements[0],
              case let .bytes(data) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid PlutusScript primitive")
        }
        
        self = Self.fromVersion(version, data: data)
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .plutusV1Script(let script):
            return .list([.int(1), .bytes(script.data)])
        case .plutusV2Script(let script):
            return .list([.int(2), .bytes(script.data)])
        case .plutusV3Script(let script):
            return .list([.int(3), .bytes(script.data)])
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
        if case let .int(version) = elements[0] {
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
            return .list([.int(1), .bytes(script.data)])
        case .plutusV2Script(let script):
            return .list([.int(2), .bytes(script.data)])
        case .plutusV3Script(let script):
            return .list([.int(3), .bytes(script.data)])
        }
    }
}

// MARK: - RawDatum
public enum RawDatum: CBORSerializable, Equatable, Hashable {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case cborTag(CBORTag)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plutusData = try? container.decode(PlutusData.self) {
            self = .plutusData(plutusData)
        } else if let dict = try? container.decode(Dictionary<AnyValue, AnyValue>.self) {
            self = .dict(dict)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let bytes = try? container.decode(Data.self) {
            self = .bytes(bytes)
        } else if let list = try? container.decode(IndefiniteList<AnyValue>.self) {
            self = .indefiniteList(list)
        } else if let cborData = try? container.decode(Data.self) {
            let cbor = try CBORSerialization.cbor(from: cborData)
            if case let CBOR.tagged(tag, data) = cbor {
                self = .cborTag(
                    CBORTag(
                        tag: UInt64(tag.rawValue),
                        value: data.unwrapped as! AnyValue
                    )
                )
            } else {
                self = .cbor(cbor)
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid RawDatum data")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .plutusData(let plutusData):
                try container.encode(plutusData)
            case .dict(let dict):
                try container.encode(dict)
            case .int(let int):
                try container.encode(int)
            case .bytes(let bytes):
                try container.encode(bytes)
            case .indefiniteList(let list):
                try container.encode(list)
            case .cbor(let cbor):
                try container.encode(try CBORSerialization.data(from: cbor))
            case .cborTag(let tag):
                try container.encode(tag)
        }
    }
    
    public static func == (lhs: RawDatum, rhs: RawDatum) -> Bool {
        switch (lhs, rhs) {
            case (.plutusData(let lhs), .plutusData(let rhs)):
                return lhs == rhs
            case (.dict(let lhs), .dict(let rhs)):
                return lhs == rhs
            case (.int(let lhs), .int(let rhs)):
                return lhs == rhs
            case (.bytes(let lhs), .bytes(let rhs)):
                return lhs == rhs
            case (.indefiniteList(let lhs), .indefiniteList(let rhs)):
                return lhs == rhs
            case (.cbor(let lhs), .cbor(let rhs)):
                return lhs == rhs
            case (.cborTag(let lhs), .cborTag(let rhs)):
                return lhs == rhs
            default:
                return false
        }
    }
    
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .plutusData(let data):
            self = .plutusData(data)
        case .dict(let dict):
            let convertedDict = dict.reduce(into: [:]) { result, entry in
                result[entry.key.toAnyValue()] = entry.value.toAnyValue()
            }
            self = .dict(convertedDict)
        case .int(let int):
            self = .int(int)
        case .bytes(let bytes):
            self = .bytes(bytes)
        case .indefiniteList(let list):
            self = .indefiniteList(IndefiniteList(list.map { $0.toAnyValue() }))
        case .cborSimpleValue(let cbor):
            self = .cbor(cbor)
        case .cborTag(let tag):
            self = .cborTag(tag)
        default:
            throw CardanoCoreError.deserializeError("Invalid RawDatum primitive")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .plutusData(let data):
            return try data.toPrimitive()
        case .dict(let dict):
            let convertedDict = dict.reduce(into: [:]) { result, entry in
                result[entry.key.toPrimitive()] = entry.value.toPrimitive()
            }
            return .dict(convertedDict)
        case .int(let int):
            return .int(int)
        case .bytes(let bytes):
            return .bytes(bytes)
        case .indefiniteList(let list):
                return .indefiniteList(
                    IndefiniteList(list.map { $0.toPrimitive() })
                )
        case .cbor(let cbor):
            return .cborSimpleValue(cbor)
        case .cborTag(let tag):
            return .cborTag(tag)
        }
    }
}

// MARK: - Datum
/// Plutus Datum type. A Union type that contains all valid datum types.
public enum Datum: CBORSerializable, Equatable, Hashable {

    case plutusData(PlutusData)
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case rawPlutusData(RawPlutusData)
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .plutusData(let data):
                self = .plutusData(data)
            case .dict(let dict):
                self = .dict(dict.reduce(into: [:]) { result, entry in
                    result[entry.key.toAnyValue()] = entry.value.toAnyValue()
                })
            case .int(let int):
                self = .int(int)
            case .bytes(let bytes):
                self = .bytes(bytes)
            case .indefiniteList(let list):
                self = .indefiniteList(
                    IndefiniteList(list.map { $0.toAnyValue() })
                )
            case .cborSimpleValue(let cbor):
                self = .cbor(cbor)
            default:
                throw CardanoCoreError.deserializeError("Invalid Datum")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .plutusData(let data):
                return .cborTag(try data.toShallowPrimitive())
            case .dict(let data):
                return .dict(data.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                })
            case .int(let data):
                return .int(data)
            case .bytes(let data):
                return .bytes(data)
            case .indefiniteList(let data):
                return .indefiniteList(IndefiniteList(data.map { $0.toPrimitive() }))
            case .cbor(let data):
                return .cborSimpleValue(data)
            case .rawPlutusData(let data):
                return try data.toPrimitive()
        }
            
    }
    
    public func toRawDatum() throws -> RawDatum {
        switch self {
            case .plutusData(let data):
                return .plutusData(data)
            case .dict(let data):
                return .dict(data)
            case .int(let data):
                return .int(data)
            case .bytes(let data):
                return .bytes(data)
            case .indefiniteList(let data):
                return .indefiniteList(data)
            case .cbor(let data):
                return .cbor(data)
            case .rawPlutusData(let data):
                return data.data
        }
    }
    
    public static func == (lhs: Datum, rhs: Datum) -> Bool {
        switch (lhs, rhs) {
            case (.plutusData(let a), .plutusData(let b)):
                return a == b
            case (.dict(let a), .dict(let b)):
                guard a.count == b.count else { return false }
                for (key, value1) in a {
                    guard let value2 = b[key], value1 == value2 else {
                        return false
                    }
                }
                return true
            case (.int(let a), .int(let b)):
                return a == b
            case (.bytes(let a), .bytes(let b)):
                return a == b
            case (.indefiniteList(let a), .indefiniteList(let b)):
                return a == b
            case (.cbor(let a), .cbor(let b)):
                return a == b
            case (.rawPlutusData(let a), .rawPlutusData(let b)):
                return a == b
            default:
                return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}
