//
// PlutusData.swift
//
// Swift representation of the CDDL rule:
//
// plutus_data =
//   constr<plutus_data>
//   / {* plutus_data => plutus_data}
//   / [* plutus_data]
//   / big_int
//   / bounded_bytes
//
import Foundation
import BigInt
import PotentCBOR
import PotentCodables
import OrderedCollections

/// Represents a Plutus data value (the algebraic sum from the CDDL).
/// - constructor: the "constr<plutus_data>" form: a constructor tag and zero-or-more fields
/// - map: an associative map from plutus_data keys to plutus_data values (CDDL: {* k => v })
/// - array: ordered list of plutus_data values (CDDL: [* plutus_data])
/// - bigInt: arbitrary integer (small or large) following the `big_int` definition
/// - bytes: bounded bytestring (0..64) matching `bounded_bytes`
public enum PlutusData: Serializable {
    case constructor(Constr)
    case map(OrderedDictionary<PlutusData, PlutusData>)
    case array([PlutusData])
    case indefiniteArray(IndefiniteList<PlutusData>)
    case bigInt(BigInteger)
    case bytes(Bytes)
    
    public var description: String {
        switch self {
            case .constructor(
                let c
            ): return "constructor(tag: \(String(describing: c.tag)), fields: \(c.fields))"
            case .map(let pairs): return "map(\(pairs))"
            case .array(let arr): return "array(\(arr))"
            case .indefiniteArray(let arr): return "indefiniteArray(\(arr))"
            case .bigInt(let bi): return "bigInt(\(bi))"
            case .bytes(let b): return "bytes(size: \(b.count))"
        }
    }
    
    public func hash() throws -> DatumHash {
        return try datumHash(datum: .plutusData(self))
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .cborTag(let cborTag):
                if cborTag.tag == 2 || cborTag.tag == 3 {
                    let bigInt = try BigInteger(from: primitive)
                    self = .bigInt(bigInt)
                    return
                } else {
                    let constr = try Constr(from: primitive)
                    self = .constructor(constr)
                }
            case .dict(let dict):
                var plutusDict = OrderedDictionary<PlutusData, PlutusData>()
                for (key, value) in dict {
                    let keyPlutus = try PlutusData(from: key)
                    let valuePlutus = try PlutusData(from: value)
                    plutusDict[keyPlutus] = valuePlutus
                }
                self = .map(plutusDict)
            case .orderedDict(let dict):
                var plutusDict = OrderedDictionary<PlutusData, PlutusData>()
                for (key, value) in dict {
                    let keyPlutus = try PlutusData(from: key)
                    let valuePlutus = try PlutusData(from: value)
                    plutusDict[keyPlutus] = valuePlutus
                }
                self = .map(plutusDict)
            case .list(let array):
                let plutusArray = try array.map { try PlutusData(from: $0) }
                self = .array(plutusArray)
            case .indefiniteList(let array):
                let plutusArray = IndefiniteList<PlutusData>(
                    try array.map { try PlutusData(from: $0) }
                )
                self = .indefiniteArray(plutusArray)
            case .int(_), .uint(_):
                self = .bigInt(try BigInteger(from: primitive))
            case .string(_), .byteString(_):
                self = .bytes(try Bytes(from: primitive))
            case .bytes(let data):
                let cborTag = try? CBORTag.fromCBOR(data: data)
                if cborTag != nil {
                    let constr = try Constr(from: .cborTag(cborTag!))
                    self = .constructor(constr)
                } else {
                    let bytes = try Bytes(from: primitive)
                    self = .bytes(bytes)
                }
            default:
                throw CardanoCoreError.deserializeError("Invalid PlutusData type: \(primitive)")
        }
    }
    
    // Entry points mark root
    public func toPrimitive() throws -> Primitive {
        return try toPrimitive(isRoot: true)
    }
    
    public func toPrimitive(isRoot: Bool) throws -> Primitive {
        switch self {
            case .constructor(let constr):
                var constructor = try constr.toPrimitive()
                if isRoot, case let .cborTag(cborTag) = constructor,
                   case let .indefiniteList(indefiniteList) = cborTag.value {
                    // Only transform nested constructor fields to bytes at the root
                    let newFields = try indefiniteList.getAll().map { field -> Primitive in
                        if case let .cborTag(fieldTag) = field {
                            return .bytes(try fieldTag.toCBORData())
                        }
                        return field
                    }
                    
                    let toEncode: Primitive
                    if newFields.isEmpty {
                        toEncode = .list([])
                    } else {
                        let indefiniteList = IndefiniteList<Primitive>(newFields)
                        toEncode = .indefiniteList(indefiniteList)
                    }
                    
                    constructor = .cborTag(
                        CBORTag(tag: cborTag.tag, value: toEncode)
                    )
                }
                return constructor
                
            case .array(let array):
                return .list(try array.map { try $0.toPrimitive(isRoot: false) })
                
            case .indefiniteArray(let array):
                return .indefiniteList(IndefiniteList(try array.map { try $0.toPrimitive(isRoot: false) }))
                
            case .map(let dict):
                var primitiveDict = OrderedDictionary<Primitive, Primitive>()
                for (k, v) in dict {
                    primitiveDict[try k.toPrimitive(isRoot: false)] = try v.toPrimitive(isRoot: false)
                }
                return .orderedDict(primitiveDict)
                
            case .bigInt(let bigInt):
                return try bigInt.toPrimitive()
                
            case .bytes(let bytes):
                return try bytes.toPrimitive()
        }
    }
    
    
    // MARK: - JSONSerializable
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        switch self {
            case .constructor(let constr):
                return try constr.toDict()
            case .map(let dict):
                // Build an array of {"k": ..., "v": ...} objects
                let pairs: [Primitive] = try dict.map { (kv) -> Primitive in
                    let keyPrimitive = try Primitive.fromAny(kv.key.toDict())
                    let valuePrimitive = try Primitive.fromAny(kv.value.toDict())
                    let pair = OrderedDictionary<Primitive, Primitive>(
                        uniqueKeysWithValues: [
                            .string("k"): keyPrimitive,
                            .string("v"): valuePrimitive
                        ]
                    )
                    return .orderedDict(pair)
                }
                return OrderedDictionary<Primitive, Primitive>(
                    uniqueKeysWithValues: [
                        .string("map"): .list(pairs)
                    ]
                )
            case .array(let array):
                return  OrderedDictionary<Primitive, Primitive>(
                    uniqueKeysWithValues: [
                        .string("list"): .list(try array.map {
                            try Primitive.fromAny($0.toDict())
                        })
                    ]
                )
            case .indefiniteArray(let array):
                return  OrderedDictionary<Primitive, Primitive>(
                    uniqueKeysWithValues: [
                        .string("list"): .list(try array.map {
                            try Primitive.fromAny($0.toDict())
                        })
                    ]
                )
            case .bigInt(let bigInt):
                return try bigInt.toDict()
            case .bytes(let bytes):
                return try bytes.toDict()
        }
    }
    
    /// Convert a dictionary to PlutusData
    /// - Parameter data: A dictionary representing the PlutusData.
    /// - Returns: Restored PlutusData.
    public static func fromDict(_ data: OrderedDictionary<Primitive, Primitive>) throws -> PlutusData {
        if data[.string("constructor")] != nil {
            return .constructor(try Constr.fromDict(data))
        } else if let _ = data[.string("int")] {
            return .bigInt(try BigInteger.fromDict(data))
        } else if case let .list(mapArray) = data[.string("map")] {
            var plutusDict = OrderedDictionary<PlutusData, PlutusData>()
            for item in mapArray {
                guard case let .orderedDict(pairDict) = item else {
                    throw CardanoCoreError.deserializeError("Invalid PlutusData map item")
                }
                guard case let .orderedDict(keyDict) = pairDict[.string("k")],
                      case let .orderedDict(valueDict) = pairDict[.string("v")] else {
                    throw CardanoCoreError.deserializeError("Invalid PlutusData map pair")
                }
                let keyPlutus = try PlutusData.fromDict(keyDict)
                let valuePlutus = try PlutusData.fromDict(valueDict)
                plutusDict[keyPlutus] = valuePlutus
            }
            return .map(plutusDict)
        } else if case let .list(listArray) = data[.string("list")] {
            let plutusArray = try listArray.map {
                guard case let .orderedDict(itemDict) = $0 else {
                    throw CardanoCoreError.deserializeError("Invalid PlutusData array item")
                }
                return try PlutusData.fromDict(itemDict)
            }
            return .array(plutusArray)
        } else if case let .string(bytesHex) = data[.string("bytes")] {
            let bytesData = Data(fromHex: bytesHex)
            return .bytes(try Bytes(from: bytesData))
        } else {
            throw CardanoCoreError.deserializeError("Invalid PlutusData dict: \(data)")
        }
    }
}

