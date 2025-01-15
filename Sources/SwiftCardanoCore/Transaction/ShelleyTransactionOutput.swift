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
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 3 else {
//            throw CardanoCoreError.valueError("Invalid ShelleyTransactionOutput data: \(value)")
//        }
//        
//        let address = try Address.fromPrimitive(data: list[0] as! Data)
//        let amount: Value = try Value.fromPrimitive(list[1])
//        let datumHash: DatumHash = try DatumHash.fromPrimitive(list[2])
//        
//        return ShelleyTransactionOutput(
//            address: address,
//            amount: amount,
//            datumHash: datumHash
//        ) as! T
//    }
}
