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
        guard let primitive = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
        
        guard primitive.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Invalid TransactionInput: expected 2 elements, got \(primitive.count)")
        }
        
        self.transactionId = try TransactionId(from: primitive[0])
        
        // transaction_input = [transaction_id, index : uint .size 2]
        guard case .uint = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
        self.index = try primitive[1].integer("TransactionInput index", as: UInt16.self)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .bytes(transactionId.payload),
            .uint(UInt64(index))
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
        
        let indexValue = try indexPrimitive.integer("TransactionInput index", as: UInt16.self)
        
        let transactionId = try TransactionId.fromDict(.string(txIdData))
        
        return TransactionInput(transactionId: transactionId, index: indexValue)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("transactionId")] = .string(transactionId.payload.toHex)
        dict[.string("index")] = .uint(UInt64(index))
        return .orderedDict(dict)
    }

}
