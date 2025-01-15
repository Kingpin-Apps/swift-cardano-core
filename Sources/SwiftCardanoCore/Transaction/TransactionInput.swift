import Foundation

struct TransactionInput: Codable, Hashable {
    let transactionId: TransactionId
    let index: UInt16
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionId = try container.decode(TransactionId.self)
        index = try container.decode(UInt16.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionId)
        try container.encode(index)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(transactionId)
        hasher.combine(index)
    }
}
