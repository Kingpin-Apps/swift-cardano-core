import Foundation
import CryptoKit
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
}


// MARK: - ScriptType
public enum ScriptType: CBORSerializable, Equatable, Hashable {
    
//    case bytes(Data)
    case nativeScript(NativeScript)
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plutusData = try? container.decode(PlutusData.self) {
            self = .plutusData(plutusData)
        } else if let dict = try? container.decode(Dictionary<AnyValue, AnyValue>.self) {
            self = .dict(dict)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        }  else if let list = try? container.decode(IndefiniteList<AnyValue>.self) {
            self = .indefiniteList(list)
        } else if let bytes = try? container.decode(Data.self) {
            if let cbor = try? CBORSerialization.cbor(from: bytes) {
                self = .cbor(cbor)
            } else {
                self = .bytes(bytes)
            }
        } else if let rawPlutusData = try? container.decode(RawPlutusData.self) {
            self = .rawPlutusData(rawPlutusData)
         } else {
            throw CardanoCoreError.deserializeError("Invalid Datum")
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
            case .rawPlutusData(let rawPlutusData):
                try container.encode(rawPlutusData)
        }
    }
    
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
