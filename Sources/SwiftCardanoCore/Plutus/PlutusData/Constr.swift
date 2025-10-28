import Foundation
import BigInt
import OrderedCollections
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// A constructor value: a tag (unsigned integer) and zero-or-more fields.
public struct Constr: Serializable, CustomStringConvertible, Sendable {
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ data: Primitive) throws -> Constr {
        guard case let .orderedDict(orderedDict) = data else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict format")
        }
        // Handle both .int and .uint for constructor field
        let tagValue: UInt64
        if case let .uint(tag) = orderedDict[.string("constructor")] {
            tagValue = UInt64(tag)
        } else if case let .int(tag) = orderedDict[.string("constructor")] {
            tagValue = UInt64(tag)
        } else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict: missing or invalid constructor field")
        }
        
        guard case let .list(fieldsArray) = orderedDict[.string("fields")] else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict: missing or invalid fields")
        }
        
        let fields = try fieldsArray.map {
            guard case let .orderedDict(fieldDict) = $0  else {
                throw CardanoCoreError.deserializeError("Invalid Constr field dict")
            }
            return try PlutusData.fromDict(.orderedDict(fieldDict))
        }
        return Constr(tag: tagValue, fields: fields)
    }
    
    public func toDict() throws -> Primitive {
        var data: OrderedDictionary<Primitive, Primitive> = [:]
        data[.string("constructor")] = .uint(UInt(self.tag ?? UInt64(Self.CONSTR_ID)))
        data[.string("fields")] = .list(
            try self.fields.map { field in
                try Primitive.fromAny(field.toDict())
            }
        )
        return .orderedDict(data)
    }
    
}
