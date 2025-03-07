import Foundation

public struct Transaction: Codable, Equatable, Hashable {
    public var transactionBody: TransactionBody
    public var transactionWitnessSet: TransactionWitnessSet
    public var valid: Bool = true
    public var auxiliaryData: AuxiliaryData? = nil

    public var id: TransactionId? {
        return transactionBody.id
    }
    
    public init(
        transactionBody: TransactionBody,
        transactionWitnessSet: TransactionWitnessSet,
        valid: Bool = true,
        auxiliaryData: AuxiliaryData? = nil
    ) {
        self.transactionBody = transactionBody
        self.transactionWitnessSet = transactionWitnessSet
        self.valid = valid
        self.auxiliaryData = auxiliaryData
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionBody = try container.decode(TransactionBody.self)
        transactionWitnessSet = try container.decode(TransactionWitnessSet.self)
        valid = try container.decode(Bool.self)
        auxiliaryData = try container.decodeIfPresent(AuxiliaryData.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionBody)
        try container.encode(transactionWitnessSet)
        try container.encode(valid)
        try container.encode(auxiliaryData)
    }
}
