import Foundation
import CryptoKit
import PotentCodables
import PotentCBOR

// MARK: - PlutusScript
typealias PlutusV1Script = Data
typealias PlutusV2Script = Data
typealias PlutusV3Script = Data

// MARK: - ScriptType
enum ScriptType: Codable, Equatable, Hashable {
    
//    case bytes(Data)
    case nativeScript(NativeScript)
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
    
    static func == (lhs: ScriptType, rhs: ScriptType) -> Bool {
        switch (lhs, rhs) {
            case (.nativeScript(let a), .nativeScript(let b)):
                return a == b
            case (.plutusV1Script(let a), .plutusV1Script(let b)):
                return a == b
            case (.plutusV2Script(let a), .plutusV2Script(let b)):
                return a == b
            case (.plutusV3Script(let a), .plutusV3Script(let b)):
                return a == b
            default:
                return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

// MARK: - RawDatum
enum RawDatum: Codable, Equatable, Hashable {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case cborTag(CBORTag)
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
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
                self = .cborTag(CBORTag(tag: Int(tag.rawValue), value: data))
            } else {
                self = .cbor(cbor)
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid RawDatum data")
        }
    }

    func encode(to encoder: Encoder) throws {
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

    
//    func toCBOR() throws -> Data {
//        switch self {
//            case .plutusData(let plutusData):
//                return try CBORSerialization.data(
//                    from: CBOR.fromAny(plutusData)
//                )
//            case .dict(let dict):
//                return try CBORSerialization.data(
//                    from: CBOR.fromAny(dict)
//                )
//            case .int(let int):
//                return try CBORSerialization.data(
//                    from: CBOR.unsignedInt(UInt64(int))
//                )
//            case .bytes(let bytes):
//                return bytes
//            case .indefiniteList(let list):
//                return try CBORSerialization.data(
//                    from: CBOR.array(list.getAll().map { CBOR.fromAny($0) })
//                )
//            case .cbor(let cbor):
//                return try CBORSerialization.data(
//                    from: cbor
//                )
//            case .cborTag(let tag):
//                return try CBORSerialization.data(
//                    from: CBOR.tagged(tag, CBOR.null)
//                )
//        }
//    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
    
    static func == (lhs: RawDatum, rhs: RawDatum) -> Bool {
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
enum Datum: Codable, Equatable, Hashable {

    case plutusData(PlutusData)
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case rawPlutusData(RawPlutusData)
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
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

    func encode(to encoder: Encoder) throws {
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
    
//    func toCBOR() throws -> Data {
//        switch self {
//            case .plutusData(let plutusData):
//                return try plutusData.toCBOR()
//            case .dict(let dict):
//                return try CBORSerialization.data(
//                    from: CBOR.fromAny(dict)
//                )
//            case .int(let int):
//                return try CBORSerialization.data(
//                    from: CBOR.unsignedInt(UInt64(int))
//                )
//            case .bytes(let bytes):
//                return try CBORSerialization.data(
//                    from: CBOR.byteString(bytes)
//                )
//            case .indefiniteList(let list):
//                return try CBORSerialization.data(
//                    from: CBOR.array(list.getAll().map { CBOR.fromAny($0) })
//                )
//            case .cbor(let cbor):
//                return try CBORSerialization.data(
//                    from: cbor
//                )
//            case .rawPlutusData(let rawPlutusData):
//                return try rawPlutusData.data.toCBOR()
//        }
//    }
    
    static func == (lhs: Datum, rhs: Datum) -> Bool {
        switch (lhs, rhs) {
            case (.plutusData(let a), .plutusData(let b)):
                let hash1 = try! a.hash()
                let hash2 = try! b.hash()
                return hash1 == hash2
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}
