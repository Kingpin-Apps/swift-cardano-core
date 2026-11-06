import Foundation
import CBORCodable
import SwiftNaCl

/// Protocol for types that can be parameterized with generic type arguments
public protocol ParameterizedType {
    /// The generic type itself.
    static var baseType: Any.Type { get }
    /// The type arguments, in order.
    static var parameterTypes: [Any.Type] { get }
}

/// Generic list type
public struct List<T>: ParameterizedType {
    /// The type `List<T>`.
    public static var baseType: Any.Type { List<T>.self }
    /// The element type, `T`.
    public static var parameterTypes: [Any.Type] { [T.self] }
}

/// Generic map type
public struct Map<K, V>: ParameterizedType {
    /// The type `Map<K, V>`.
    public static var baseType: Any.Type { Map<K, V>.self }
    /// The key and value types, `K` and `V`.
    public static var parameterTypes: [Any.Type] { [K.self, V.self] }
}

/// Generic union type
public struct Union<T, U>: ParameterizedType {
    /// The type `Union<T, U>`.
    public static var baseType: Any.Type { Union<T, U>.self }
    /// The two member types, `T` and `U`.
    public static var parameterTypes: [Any.Type] { [T.self, U.self] }
}

/// The hash of a datum: a Blake2b hash of its CBOR encoding, `DATUM_HASH_SIZE` bytes long.
///
/// - Parameter datum: The datum to hash.
/// - Returns: The datum hash.
/// - Throws: When the datum cannot be encoded or hashed.
public func datumHash(datum: Datum) throws -> DatumHash {
    let cborBytes = try CBOREncoder().encode(datum)
    let hash = try Hash().blake2b(
        data: cborBytes,
        digestSize: DATUM_HASH_SIZE,
        encoder: RawEncoder.self
    )
    return DatumHash(payload: hash)
}

/// The hash of a script. The same as ``scriptHash(script:)``.
///
/// - Parameter script: The script to hash.
/// - Returns: The script hash.
/// - Throws: When the script cannot be hashed.
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

/// The compact CBOR tag for a Plutus data constructor index.
///
/// Constructors 0 to 6 use tags 121 to 127, and constructors 7 to 127 use tags 1280 to 1400. Other constructors have no compact tag and are written with the general tag 102.
///
/// - Parameter constrID: The constructor index.
/// - Returns: The tag, or `nil` when the constructor has no compact tag.
public func getTag(constrID: Int) -> Int? {
    if 0 <= constrID && constrID < 7 {
        return 121 + constrID
    } else if 7 <= constrID && constrID < 128 {
        return 1280 + (constrID - 7)
    } else {
        return nil
    }
}

/// Reads the constructor index and fields of a tagged Plutus data constructor.
///
/// Accepts the compact tags 121 to 127 and 1280 to 1400, with a definite- or indefinite-length field array, and the general form `#6.102([constructor, [fields]])`.
///
/// - Parameter value: The tagged CBOR value.
/// - Returns: The constructor index and its fields.
/// - Throws: When the value is not tagged, the tag is not a constructor tag, or the content has the wrong shape.
public func getConstructorIDAndFields(value: CBOR) throws -> (Int, [AnyValue]) {
    guard case let CBOR.tagged(tag, innerValue) = value else {
        throw CardanoCoreError.deserializeError(
            "Value does not match the data schema of AlonzoMetadata.")
    }

    if tag == 102 {
        guard innerValue.arrayValue?.count == 2 else {
            throw
                CardanoCoreError
                .decodingError(
                    "Expect the length of value to be exactly 2, got \(String(describing: innerValue.count)) instead."
                )
        }
        guard let parts = innerValue.arrayValue,
              let alternative = parts[0].unwrapped as? UInt64,
              let constr = Int(exactly: alternative),
              let fields = parts[1].unwrapped as? [Any]
        else {
            throw CardanoCoreError.decodingError(
                "A #6.102 constructor must be [alternative, [fields]], got \(innerValue)")
        }
        return (constr, try fields.map { try AnyValue.wrapped($0) })
    } else {
        var constr: Int
        if 121 <= tag && tag < 128 {
            constr = Int(tag - 121)
        } else if 1280 <= tag && tag <= 1400 {
            constr = Int(tag - 1280 + 7)
        } else {
            throw
                CardanoCoreError
                .decodingError("Unexpected tag for RawPlutusData: \(tag)")
        }
        
        if innerValue.arrayValue != nil {
            return (
                constr,
                try innerValue.arrayValue!
                    .map {
                        try $0.toPrimitive().toAnyValue()
                    }
            )
        } else if innerValue.indefiniteArrayValue != nil {
            return (
                constr,
                try innerValue.indefiniteArrayValue!.map { try $0.toPrimitive().toAnyValue() }
            )
        } else {
            throw
            CardanoCoreError
                .decodingError("Unexpected value for RawPlutusData: \(innerValue)")
        }
    }
}

/// Constructs a unique representation of a PlutusData type definition.
/// Intended for automatic constructor generation.
/// - Parameters:
///   - cls: The PlutusData type to represent.
///   - skipConstructor: Whether to skip the constructor ID.
/// - Throws: CardanoException if the type is not supported.
/// - Returns: A unique representation of the PlutusData type.
public func idMap(cls: Any, skipConstructor: Bool = false) throws -> String {
    if ((cls as? Data) != nil) || ((cls as? [UInt8]) != nil) {
        return "bytes"
    } else if cls as? any Any.Type == Int.self || cls is any BinaryInteger.Type {
        return "int"
    } else if cls as? any Any.Type == CBOR.self || cls as? any Any.Type == RawPlutusData.self
        || cls as? any Any.Type == Datum.self
    {
        return "any"
    } else if cls as? any Any.Type == IndefiniteList<AnyValue>.self {
        return "list"
    }

    // Handle parameterized types
    if let genericType = cls as? ParameterizedType.Type {
        let baseType = genericType.baseType
        let parameterDescriptions = try genericType.parameterTypes.map { try idMap(cls: $0) }
            .joined(separator: ",")

        if baseType == List<Any>.self {
            return "list<\(parameterDescriptions)>"
        } else if baseType == Map<Any, Any>.self {
            return "map<\(parameterDescriptions)>"
        } else if baseType == Union<Any, Any>.self {
            return "union<\(parameterDescriptions)>"
        } else {
            throw CardanoCoreError.typeError(
                "Unexpected parameterized type for automatic constructor generation: \(cls)")
        }
    }

    // Handle PlutusData types
    if let plutusType = cls as? Constr.Type {
        let mirror = Mirror(reflecting: plutusType)
        let fieldsDescription = try mirror.children.map {
            "\($0.label ?? ""):\(try idMap(cls: $0.value.self as! AnyClass))"
        }.joined(separator: ",")

        let constructorPart = skipConstructor ? "_" : String(plutusType.CONSTR_ID)
        return "cons[\(String(describing: plutusType))](\(constructorPart);\(fieldsDescription))"
    }

    // Unexpected type
    throw CardanoCoreError.typeError("Unexpected type for automatic constructor generation: \(cls)")
}
