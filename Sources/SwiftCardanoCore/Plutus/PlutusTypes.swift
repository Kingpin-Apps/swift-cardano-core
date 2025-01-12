import Foundation
import CryptoKit
import PotentCBOR

// MARK: - PlutusScript
typealias PlutusV1Script = Data
typealias PlutusV2Script = Data
typealias PlutusV3Script = Data

// MARK: - ScriptType
enum ScriptType {
    case bytes(Data)
    case nativeScript(NativeScript)
    case plutusV1Script(PlutusV1Script)
    case plutusV2Script(PlutusV2Script)
    case plutusV3Script(PlutusV3Script)
}

// MARK: - RawDatum
enum RawDatum {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyHashable, Any>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<Any>)
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
}

// MARK: - Datum
/// Plutus Datum type. A Union type that contains all valid datum types.
enum Datum {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyHashable, Any>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<Any>)
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
}
