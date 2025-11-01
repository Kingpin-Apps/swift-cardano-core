import Foundation
import OrderedCollections

public struct TransactionInput: Serializable {
    public let transactionId: TransactionId
    public let index: UInt16
    
    public var description: String { "\(transactionId.description)#\(index)" }
    
    public var debugDescription: String { self.description }
    
    public init(transactionId: TransactionId, index: UInt16) {
        self.transactionId = transactionId
        self.index = index
    }
    
    public init(from txId: String) throws {
        let components = txId.split(separator: "#")
        guard components.count == 2,
        let index = UInt16(components[1]) else {
            throw CardanoCoreError.valueError("Invalid TransactionInput string format")
        }
        try self.init(from: String(components[0]), index: index)
    }
    
    public init(from transactionId: String, index: UInt16) throws {
        self.transactionId = try TransactionId(from: .string(transactionId))
        self.index = index
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
        
        self.transactionId = try TransactionId(from: primitive[0])
        
        switch primitive[1] {
            case let .uint(intValue):
                self.index = UInt16(intValue)
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .bytes(transactionId.payload),
            .uint(UInt(index))
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> TransactionInput {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid TransactionInput dictionary")
        }
        
        guard let txIdPrimitive = dictValue[.string("transactionId")],
              case let .string(txIdData) = txIdPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid transactionId in TransactionInput")
        }
        
        guard let indexPrimitive = dictValue[.string("index")] else {
            throw CardanoCoreError.deserializeError("Missing index in TransactionInput")
        }
        
        let indexValue: UInt16
        switch indexPrimitive {
        case let .uint(uintValue):
            indexValue = UInt16(uintValue)
        case let .int(intValue):
            indexValue = UInt16(intValue)
        default:
            throw CardanoCoreError.deserializeError("Invalid index type in TransactionInput")
        }
        
        let transactionId = try TransactionId.fromDict(.string(txIdData))
        
        return TransactionInput(transactionId: transactionId, index: indexValue)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("transactionId")] = .string(transactionId.payload.toHex)
        dict[.string("index")] = .uint(UInt(index))
        return .orderedDict(dict)
    }

}
