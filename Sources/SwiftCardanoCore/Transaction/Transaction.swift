import Foundation

let _MAX_INT64: Int64 = (1 << 63) - 1
let _MIN_INT64: Int64 = -(1 << 63)

struct Transaction: Codable {
    var transactionBody: TransactionBody
    var transactionWitnessSet: TransactionWitnessSet
    var valid: Bool = true
    var auxiliaryData: AuxiliaryData? = nil

    var id: TransactionId? {
        return transactionBody.id
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionBody = try container.decode(TransactionBody.self)
        transactionWitnessSet = try container.decode(TransactionWitnessSet.self)
        valid = try container.decode(Bool.self)
        auxiliaryData = try container.decodeIfPresent(AuxiliaryData.self)
    }

    func encode(to encoder: Encoder) throws {
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
class Withdrawals: Codable {
    typealias KEY_TYPE = RewardAccount
    typealias VALUE_TYPE = Coin
    
    var data: [KEY_TYPE: VALUE_TYPE] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    private var _data: [KEY_TYPE: VALUE_TYPE] = [:]
    
    // Subscript for easier key-value access
    subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }
}
