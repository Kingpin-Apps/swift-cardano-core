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
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// Represents a Plutus data value (the algebraic sum from the CDDL).
/// - constructor: the "constr<plutus_data>" form: a constructor tag and zero-or-more fields
/// - map: an associative map from plutus_data keys to plutus_data values (CDDL: {* k => v })
/// - array: ordered list of plutus_data values (CDDL: [* plutus_data])
/// - bigInt: arbitrary integer (small or large) following the `big_int` definition
/// - bytes: bounded bytestring (0..64) matching `bounded_bytes`
public enum PlutusData: CBORSerializable, CustomStringConvertible {
    case constructor(Constr)
    case map(OrderedDictionary<PlutusData, PlutusData>)
    case array([PlutusData])
    case indefiniteArray(IndefiniteList<PlutusData>)
    case bigInt(BigInteger)
    case bytes(BoundedBytes)
    
    public var description: String {
        switch self {
            case .constructor(
                let c
            ): return "constructor(tag: \(String(describing: c.tag)), fields: \(c.fields))"
            case .map(let pairs): return "map(\(pairs))"
            case .array(let arr): return "array(\(arr))"
            case .indefiniteArray(let arr): return "indefiniteArray(\(arr))"
            case .bigInt(let bi): return "bigInt(\(bi))"
            case .bytes(let b): return "bytes(size: \(b.bytes.count))"
        }
    }
    
    public func hash() throws -> DatumHash {
        return try datumHash(datum: .plutusData(self))
    }
    
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
            case .int(_):
                let bigInt = try BigInteger(from: primitive)
                self = .bigInt(bigInt)
            case .uint(_):
                let bigUInt = try BigInteger(from: primitive)
                self = .bigInt(bigUInt)
            case .bytes(let data):
                let cborTag = try? CBORTag.fromCBOR(data: data)
                if cborTag != nil {
                    let constr = try Constr(from: .cborTag(cborTag!))
                    self = .constructor(constr)
                } else {
                    let boundedBytes = try BoundedBytes(from: primitive)
                    self = .bytes(boundedBytes)
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
    
    public func toDict() throws -> [AnyHashable: Any] {
        switch self {
            case .constructor(let constr):
                return try constr.toDict()
            case .map(let dict):
                return [
                    "map": try dict.map { ["k": try $0.key.toDict(), "v": try $0.value.toDict()] }
                ]
            case .array(let array):
                return  ["list": try array.map { try $0.toDict() }]
            case .indefiniteArray(let array):
                return  ["list": try array.map { try $0.toDict() }]
            case .bigInt(let bigInt):
                return try bigInt.toDict()
            case .bytes(let bytes):
                return try bytes.toDict()
        }
    }
    
    /// Convert to a json string
    /// - Returns: A JSON encoded PlutusData.
    public func toJSON() throws -> String {
        let dict = try self.toDict()
        let jsonData = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys]
        )
        return String(data: jsonData, encoding: .utf8)!
    }
    
    /// Convert a dictionary to PlutusData
    /// - Parameter data: A dictionary representing the PlutusData.
    /// - Returns: Restored PlutusData.
    public static func fromDict(_ data: [AnyHashable: Any]) throws -> PlutusData {
        if let _ = data["constructor"] as? UInt64 {
            return try Constr.fromDict(data)
        } else if let mapArray = data["map"] as? [Any] {
            var plutusDict = OrderedDictionary<PlutusData, PlutusData>()
            for item in mapArray {
                guard let pairDict = item as? [String: Any],
                      let keyData = pairDict["k"] as? [String: Any],
                      let valueData = pairDict["v"] as? [String: Any] else {
                    throw CardanoCoreError.deserializeError("Invalid PlutusData map item")
                }
                let keyPlutus = try PlutusData.fromDict(keyData)
                let valuePlutus = try PlutusData.fromDict(valueData)
                plutusDict[keyPlutus] = valuePlutus
            }
            return .map(plutusDict)
        } else if let listArray = data["list"] as? [Any] {
            let plutusArray = try listArray.map {
                guard let itemDict = $0 as? [String: Any] else {
                    throw CardanoCoreError.deserializeError("Invalid PlutusData array item")
                }
                return try PlutusData.fromDict(itemDict)
            }
            return .array(plutusArray)
        } else if let intData = data["int"] as? Int {
            return .bigInt(.int(Int64(intData)))
        } else if let intData = data["int"] as? UInt {
            return .bigInt(.int(Int64(intData)))
        } else if let intData = data["int"] as? UInt64 {
            return .bigInt(.int(Int64(intData)))
        } else if let intData = data["int"] as? Int64 {
            return .bigInt(.int(intData))
        } else if let intBigUInt = data["int"] as? BigUInt {
            return .bigInt(.bigUInt(intBigUInt))
        } else if let intBigNInt = data["int"] as? BigInt {
            return .bigInt(.bigNInt(intBigNInt))
        } else if let intData = data["int"] as? BigInteger {
            return .bigInt(.int(intData.intValue))
        } else if let bytesHex = data["bytes"] as? String {
            let bytesData = Data(fromHex: bytesHex)
            let boundedBytes = try BoundedBytes(bytes: bytesData)
            return .bytes(boundedBytes)
        } else {
            throw CardanoCoreError.deserializeError("Invalid PlutusData dict: \(data)")
        }
    }
    
    /// Restore a json encoded string to a PlutusData.
    /// - Parameter data: An encoded json string.
    /// - Returns: The restored PlutusData.
    public static func fromJSON(_ data: String) throws -> PlutusData {
        let jsonData = data.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        return try Self.fromDict(dict)
    }
}

/// A constructor value: a tag (unsigned integer) and zero-or-more fields.
public struct Constr: CBORSerializable, CustomStringConvertible {
    /// Constructor tag (aka: constructor index)
    /// In CDDL the constructors may be encoded with a CBOR constructor tag.
    public let tag: UInt64?
    /// Fields of the constructor
    public let fields: [PlutusData]
    
    public var useIndefiniteList: Bool?
    
    public init(tag: UInt64?, fields: [PlutusData] = [], useIndefiniteList: Bool? = nil) {
        self.tag = tag
        self.fields = fields
        self.useIndefiniteList = useIndefiniteList ?? true
    }
    
    public static var constrID: Int {
        let detString = try! idMap(cls: Self.self, skipConstructor: true)
        let detHash = SHA256.hash(data: Data(detString.utf8)).map { String(format: "%02x", $0) }
            .joined()
        let num = BigInt(detHash, radix: 16)
        let calc = num! % (1 << 32)
        
        return Int(calc)
    }
    
    public static var CONSTR_ID: Int {
        return Self.constrID
    }
    
    public var description: String {
        "Constr(tag: \(String(describing: tag)), fields: \(fields))"
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(cborTag) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Constr type")
        }
        
        if cborTag.tag == 102 {
            guard case let .list(valueArray) = cborTag.value,
                  valueArray.count == 2,
                  case let .uint(tag) = valueArray[0]
            else {
                throw CardanoCoreError.deserializeError(
                    "Invalid CBORTag format for PlutusData. Expected array of length 2 with integer tag but got: \(cborTag)"
                )
            }
            
            let fields: [Primitive]
            if case let .list(list) = valueArray[1] {
                fields = list
            } else if case let .indefiniteList(indefiniteList) = valueArray[1] {
                fields = indefiniteList.getAll()
            } else {
                throw CardanoCoreError.deserializeError("Expected array of fields but got: \(valueArray[1])")
            }
            
            self.tag = UInt64(tag)
            self.fields = try fields.map { try PlutusData(from: $0) }
            self.useIndefiniteList = true
        } else {
            let fields: [Primitive]
            if case let .list(list) = cborTag.value {
                fields = list
            } else if case let .indefiniteList(indefiniteList) = cborTag.value {
                fields = indefiniteList.getAll()
            } else {
                throw CardanoCoreError.deserializeError("Expected array of fields but got: \(cborTag.value)")
            }
            
            self.tag = cborTag.tag
            self.fields = try fields.map { try PlutusData(from: $0) }
            self.useIndefiniteList = true
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        let calculatedTag = getTag(constrID: Int(self.tag!))
        
        let primitives = try fields.map {
            try $0.toPrimitive(isRoot: false)
        }
        
        let toEncode: Primitive
        if primitives.isEmpty {
            toEncode = .list([])
        } else {
            let indefiniteList = IndefiniteList<Primitive>(primitives)
            toEncode = .indefiniteList(indefiniteList)
        }
        
        if calculatedTag != nil {
            return .cborTag(
                CBORTag(tag: UInt64(calculatedTag!), value: toEncode)
            )
        } else {
            let tagToUse = self.tag ?? UInt64(Self.CONSTR_ID)
            
            if self.useIndefiniteList! {
                return .cborTag(
                    CBORTag(
                        tag: 102,
                        value: .list([
                            .int(Int(tagToUse)),
                            toEncode
                        ])
                    )
                )
            } else {
                return .cborTag(
                    CBORTag(
                        tag: 102,
                        value: .list([
                            .int(Int(tagToUse)),
                            .list(primitives)
                        ])
                    )
                )
            }
        }
    }
    
    public func toDict() throws -> [String: Any] {
        return [
            "constructor": tag ?? Self.CONSTR_ID,
            "fields": try fields.map { try $0.toDict() },
        ]
    }
    
    public static func fromDict(_ data: [AnyHashable: Any]) throws -> PlutusData {
        guard let tag = data["constructor"] as? UInt64,
              let fieldsArray = data["fields"] as? [Any] else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict")
        }
        let fields = try fieldsArray.map {
            guard let fieldDict = $0 as? [String: Any] else {
                throw CardanoCoreError.deserializeError("Invalid Constr field dict")
            }
            return try PlutusData.fromDict(fieldDict)
        }
        return .constructor(Constr(tag: tag, fields: fields))
    }
    
}

/// Representation of a big integer according to the CDDL's `big_int` description:
/// big_int = int / big_uint / big_nint
/// big_uint = #6.2(bounded_bytes)
/// big_nint = #6.3(bounded_bytes)
///
/// This enum keeps small signed ints (that fit in Int64) separately and otherwise stores
/// magnitude bytes for big unsigned/negative integers.
public enum BigInteger: CBORSerializable, CustomStringConvertible {
    case int(Int64)         // small (fits in Int64)
    case bigUInt(BigUInt)      // magnitude bytes for a large unsigned integer (CBOR tag 2)
    case bigNInt(BigInt)      // magnitude bytes for a large negative integer (CBOR tag 3)
    
    public var description: String {
        switch self {
            case .int(let v): return "Int(\(v))"
            case .bigUInt(let d): return "BigUInt(\(d))"
            case .bigNInt(let d): return "BigNInt(-\(d))"
        }
    }
    
    public var intValue : Int64 {
        switch self {
            case .int(let v):
                return v
            case .bigUInt(let bigUInt):
                return Int64(bigUInt)
            case .bigNInt(let bigNInt):
                return Int64(-1*bigNInt)
        }
    }
    
    public var bigUIntValue : BigUInt {
        switch self {
            case .int(let v):
                return BigUInt(v)
            case .bigUInt(let bigUInt):
                return bigUInt
            case .bigNInt(let bigNInt):
                return BigUInt(-1*bigNInt)
        }
    }
    
    public var bigNIntValue : BigInt {
        switch self {
            case .int(let v):
                return BigInt((v))
            case .bigUInt(let bigUInt):
                return BigInt(BigUInt(bigUInt))
            case .bigNInt(let bigNInt):
                return bigNInt
        }
    }
    
    /// Convenience initializer for unsigned magnitude bytes.
    /// The bytes are expected in big-endian form.
    public init(bigUIntBytes bigUInt: BigUInt) throws {
        self = .bigUInt(bigUInt)
    }
    
    /// Convenience initializer for negative magnitude bytes.
    /// The bytes are expected in big-endian form for the absolute value.
    public init(bigNIntBytes bigNInt: BigInt) throws {
        self = .bigNInt(bigNInt)
    }
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .int(let v):
                self = .int(Int64(v))
            case .uint(let v):
                self = .int(Int64(v))
            case .cborTag(let tag) where tag.tag == 2:
                guard case let .bytes(bigUInt) = tag.value else {
                    throw CardanoCoreError.deserializeError("Invalid bigUInt CBOR tag value: \(tag.value)")
                }
                self = .bigUInt(try CBORDecoder().decode(
                    BigUInt.self,
                    from: bigUInt
                ))
            case .cborTag(let tag) where tag.tag == 3:
                guard case let .bytes(bigNInt) = tag.value else {
                    throw CardanoCoreError.deserializeError("Invalid bigNInt CBOR tag value: \(tag.value)")
                }
                self = .bigNInt(try CBORDecoder().decode(
                    BigInt.self,
                    from: bigNInt
                ))
            default:
                throw CardanoCoreError.deserializeError("Invalid BigInt type: \(primitive)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .int(let v):
                return .int(Int(v))
            case .bigUInt(let bigUInt):
                return .bigUInt(bigUInt)
            case .bigNInt(let bigNInt):
                return .bigInt(bigNInt)
        }
    }
    
    public func toDict() throws -> [String: any BinaryInteger] {
        switch self {
            case .int(let v):
                return ["int": Int(v)]
            case .bigUInt(let d):
                return ["int": d]
            case .bigNInt(let d):
                return ["int": -1*d]
        }
    }
}

/// Bounded bytes with enforced maximum length (0..64).
/// Mirrors the CDDL `bounded_bytes = bytes .size (0 .. 64)`
public struct BoundedBytes: CBORSerializable, CustomStringConvertible {
    public let bytes: Data
    
    /// Creates a `BoundedBytes` if `bytes.count` is <= 64. Returns nil otherwise.
    public init(bytes: Data) throws {
        guard bytes.count <= 64 else {
            throw CardanoCoreError.valueError("BoundedBytes length exceeds 64 bytes")
        }
        self.bytes = bytes
    }
    
    /// Create from an array of bytes
    public init(_ bytesArray: [UInt8]) throws {
        try self.init(bytes: Data(bytesArray))
    }
    
    public var description: String {
        "BoundedBytes(length: \(bytes.count))"
    }
    
    public var toHex: String {
        return self.bytes.toHex
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid BoundedBytes type")
        }
        try self.init(bytes: data)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(self.bytes)
    }
    
    public func toDict() throws -> [String: String] {
        return ["bytes": bytes.toHex]
    }
}

// MARK: - PlutusDataProtocol

protocol PlutusDataProtocol: CBORSerializable {
    init(from plutusData: PlutusData) throws
    
    func toPlutusData() throws -> PlutusData
}

extension PlutusDataProtocol {
    public init(from primitive: Primitive) throws {
        let plutusData = try PlutusData(from: primitive)
        try self.init(from: plutusData)
    }
    
    public init(from dict: [AnyHashable: Any]) throws {
        let plutusData = try PlutusData.fromDict(dict)
        try self.init(from: plutusData)
    }
    
    public func hash() throws -> DatumHash {
        let plutusData = try self.toPlutusData()
        return try datumHash(datum: .plutusData(plutusData))
    }
    
    public func toPrimitive() throws -> Primitive {
        return try self.toPlutusData().toPrimitive()
    }
    
    public func toJSON() throws -> String {
        let plutusData = try self.toPlutusData()
        return try plutusData.toJSON()
    }
    
    public func toDict() throws -> [AnyHashable: Any] {
        let plutusData = try self.toPlutusData()
        return try plutusData.toDict()
    }
    
    public static func fromJSON(_ data: String) throws -> Self {
        let plutusData = try PlutusData.fromJSON(data)
        return try Self.init(from: plutusData)
    }
    
    public static func fromDict(_ data: [AnyHashable: Any]) throws -> Self {
        let plutusData = try PlutusData.fromDict(data)
        return try Self.init(from: plutusData)
    }
    
    // Eqauality implementation
    public static func == (lhs: Self, rhs: Self) -> Bool {
        do {
            let lhsPlutus = try lhs.toPlutusData()
            let rhsPlutus = try rhs.toPlutusData()
            return lhsPlutus.description == rhsPlutus.description
        } catch {
            return false
        }
    }
}


/// The default "Unit type" with a 0 constructor ID
public struct Unit: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 0
    
    public init() {}
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(Self.CONSTR_ID)) ?? 0)
        guard case let .constructor(constr) = plutusData,
              constr.tag == expectedTag || constr.tag == Self.CONSTR_ID,
              constr.fields.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid Unit PlutusData")
        }
    }
    
    public func toPlutusData() throws -> PlutusData {
        return PlutusData.constructor(Constr(tag: 0, fields: []))
    }
}
