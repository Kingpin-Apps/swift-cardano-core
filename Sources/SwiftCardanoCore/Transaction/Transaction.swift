import Foundation

let _MAX_INT64: Int64 = (1 << 63) - 1
let _MIN_INT64: Int64 = -(1 << 63)

public struct Transaction: Codable {
    var transactionBody: TransactionBody
    var transactionWitnessSet: TransactionWitnessSet
    var valid: Bool = true
    var auxiliaryData: AuxiliaryData? = nil

    var id: TransactionId? {
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

/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
public struct Withdrawals: Codable {
    public var data: [RewardAccount: Coin] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    private var _data: [RewardAccount: Coin] = [:]
    
    // Subscript for easier key-value access
    public subscript(key: RewardAccount) -> Coin? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }
}
