import Foundation

public struct TransactionInput: CBORSerializable, Equatable, Hashable {
    public let transactionId: TransactionId
    public let index: UInt16
    
    public init(transactionId: TransactionId, index: UInt16) {
        self.transactionId = transactionId
        self.index = index
    }
    
    public init(from transactionId: String, index: UInt16) throws {
        self.transactionId = try TransactionId(from: .string(transactionId))
        self.index = index
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
        
        self.transactionId = try TransactionId(from: primitive[0])
        
        switch primitive[1] {
            case let .int(intValue):
                self.index = UInt16(intValue)
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionInput type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .string(transactionId.payload.toHex),
            .int(Int(index))
        ])
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionId = try container.decode(TransactionId.self)
        index = try container.decode(UInt16.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionId)
        try container.encode(index)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(transactionId)
        hasher.combine(index)
    }
}
