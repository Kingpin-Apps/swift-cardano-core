import Foundation
import CryptoKit
import PotentCBOR
import PotentCodables
import SwiftNcal


public func datumHash(datum: Datum) throws -> DatumHash {
    let cborBytes = try CBOREncoder().encode(datum)
    let hash = try Hash().blake2b(
        data: cborBytes,
        digestSize: DATUM_HASH_SIZE,
        encoder: RawEncoder.self
    )
    return DatumHash(payload: hash)
}

public func plutusScriptHash(script: ScriptType) throws -> ScriptHash {
    return try scriptHash(script: script)
}

/// Calculates the hash of a script, which could be either native script or plutus script.
/// - Parameter script: The script to hash.
public func scriptHash(script: ScriptType) throws -> ScriptHash {
    switch script {
        case .nativeScript(let nativeScript):
            return try nativeScript.scriptHash()
        case .plutusV1Script(let plutusScript):
            let hash = try Hash().blake2b(
                data: plutusScript.getScriptHashPrefix() + plutusScript.data,
                digestSize: SCRIPT_HASH_SIZE,
                encoder: RawEncoder.self
            )
            return ScriptHash(payload: hash)
        case .plutusV2Script(let plutusScript):
            let hash = try Hash().blake2b(
                data: plutusScript.getScriptHashPrefix() + plutusScript.data,
                digestSize: SCRIPT_HASH_SIZE,
                encoder: RawEncoder.self
            )
            return ScriptHash(payload: hash)
        case .plutusV3Script(let plutusScript):
            let hash = try Hash().blake2b(
                data: plutusScript.getScriptHashPrefix() + plutusScript.data,
                digestSize: SCRIPT_HASH_SIZE,
                encoder: RawEncoder.self
            )
            return ScriptHash(payload: hash)
    }
}

public func getTag(constrID: Int) -> Int? {
    if 0 <= constrID && constrID < 7 {
        return 121 + constrID
    } else if 7 <= constrID && constrID < 128 {
        return 1280 + (constrID - 7)
    } else {
        return nil
    }
}

public func getConstructorIDAndFields(value: CBOR) throws -> (Int, [Any]) {
    guard case let CBOR.tagged(tag, innerValue) = value else {
        throw CardanoCoreError.deserializeError("Value does not match the data schema of AlonzoMetadata.")
    }
    
    if tag.rawValue == 102 {
        guard innerValue.count == 2 else {
            throw CardanoCoreError
                .decodingError(
                    "Expect the length of value to be exactly 2, got \(String(describing: innerValue.count)) instead."
                )
        }
        return (Int(tag.rawValue), innerValue.unwrapped as! [Any])
    } else {
        var constr: Int
        if 121 <= tag.rawValue && tag.rawValue < 128 {
            constr = Int(tag.rawValue - 121)
        } else if 1280 <= tag.rawValue && tag.rawValue < 1536 {
            constr = Int(tag.rawValue - 1280 + 7)
        } else {
            throw CardanoCoreError
                .decodingError("Unexpected tag for RawPlutusData: \(tag)")
        }
        return (constr, innerValue.unwrapped as! [Any])
    }
}

/// Constructs a unique representation of a PlutusData type definition.
/// Intended for automatic constructor generation.
/// - Parameters:
///   - cls: The PlutusData type to represent.
///   - skipConstructor: Whether to skip the constructor ID.
/// - Throws: CardanoException if the type is not supported.
/// - Returns: A unique representation of the PlutusData type.
//func idMap(cls: Any, skipConstructor: Bool = false) throws -> String {
//    if ((cls as? Data) != nil) || ((cls as? [UInt8]) != nil) {
//        return "bytes"
//    } else if cls as? any Any.Type == Int.self || cls is any BinaryInteger.Type {
//        return "int"
//    } else if cls as? any Any.Type == CBOR.self || cls as? any Any.Type == RawPlutusData.self || cls as? any Any.Type == Datum.self {
//        return "any"
//    } else if cls as? any Any.Type == IndefiniteList<AnyValue>.self {
//        return "list"
//    }
//    
//    // Handle parameterized types
////    if let genericType = cls as? ParameterizedType.Type {
////        let baseType = genericType.baseType
////        let parameterDescriptions = try genericType.parameterTypes.map { try idMap(cls: $0) }.joined(separator: ",")
////        
////        if baseType == List.self {
////            return "list<\(parameterDescriptions)>"
////        } else if baseType == Map.self {
////            return "map<\(parameterDescriptions)>"
////        } else if baseType == Union.self {
////            return "union<\(parameterDescriptions)>"
////        } else {
////            throw NSError(
////                domain: "Unexpected parameterized type for automatic constructor generation: \(cls)",
////                code: 0,
////                userInfo: nil
////            )
////        }
////    }
//    
//    // Handle PlutusData types
//    if let plutusType = cls as? PlutusData.Type {
//        
//        let mirror = Mirror(reflecting: plutusType)
//        let fieldsDescription = try mirror.children.map {
//            "\($0.label ?? ""):\(try idMap(cls: $0.value.self as! AnyClass))"
//        }.joined(separator: ",")
//        
//        return "cons[\(String(describing: plutusType))](\(skipConstructor ? "_" : plutusType.CONSTR_ID);\(fieldsDescription))"
//    }
//    
//    // Unexpected type
//    throw CardanoCoreError.typeError("Unexpected type for automatic constructor generation: \(cls)")
//}
