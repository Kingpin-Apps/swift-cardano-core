import Foundation
import CryptoKit
import PotentCBOR

// MARK: - PlutusScript
typealias PlutusV1Script = Data
typealias PlutusV2Script = Data
typealias PlutusV3Script = Data

// MARK: - ScriptType
enum ScriptType: Equatable, Hashable {
    
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
enum RawDatum: Equatable, Hashable {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyHashable, AnyHashable>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyHashable>)
    case cbor(CBOR)
    case cborTag(CBOR.Tag)
    
    func toCBOR() throws -> Data {
        switch self {
            case .plutusData(let plutusData):
                return try plutusData.toCBOR()
            case .dict(let dict):
                return try CBORSerialization.data(
                    from: CBOR.fromAny(dict)
                )
            case .int(let int):
                return try CBORSerialization.data(
                    from: CBOR.unsignedInt(UInt64(int))
                )
            case .bytes(let bytes):
                return bytes
            case .indefiniteList(let list):
                return try CBORSerialization.data(
                    from: CBOR.array(list.getAll().map { CBOR.fromAny($0) })
                )
            case .cbor(let cbor):
                return try CBORSerialization.data(
                    from: cbor
                )
            case .cborTag(let tag):
                return try CBORSerialization.data(
                    from: CBOR.tagged(tag, CBOR.null)
                )
        }
    }
    
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
enum Datum: Equatable, Hashable {

    case plutusData(PlutusData)
    case dict(Dictionary<AnyHashable, AnyHashable>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyHashable>)
    case cbor(CBOR)
    case rawPlutusData(RawPlutusData)
    
    func toCBOR() throws -> Data {
        switch self {
            case .plutusData(let plutusData):
                return try plutusData.toCBOR()
            case .dict(let dict):
                return try CBORSerialization.data(
                    from: CBOR.fromAny(dict)
                )
            case .int(let int):
                return try CBORSerialization.data(
                    from: CBOR.unsignedInt(UInt64(int))
                )
            case .bytes(let bytes):
                return try CBORSerialization.data(
                    from: CBOR.byteString(bytes)
                )
            case .indefiniteList(let list):
                return try CBORSerialization.data(
                    from: CBOR.array(list.getAll().map { CBOR.fromAny($0) })
                )
            case .cbor(let cbor):
                return try CBORSerialization.data(
                    from: cbor
                )
            case .rawPlutusData(let rawPlutusData):
                return try rawPlutusData.data.toCBOR()
        }
    }
    
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
