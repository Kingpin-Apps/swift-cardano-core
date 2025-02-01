import Foundation

struct ShelleyTransactionOutput: Codable {
    var address: Address
    var amount: Value
    var datumHash: DatumHash?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        address = try container.decode(Address.self)
        amount = try container.decode(Value.self)
        datumHash = try container.decode(DatumHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(address)
        try container.encode(amount)
        try container.encode(datumHash)
    }
}
