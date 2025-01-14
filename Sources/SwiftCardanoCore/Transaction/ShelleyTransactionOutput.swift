import Foundation

struct ShelleyTransactionOutput: ArrayCBORSerializable {
    var address: Address
    var amount: Value
    var datumHash: DatumHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 3 else {
            throw CardanoCoreError.valueError("Invalid ShelleyTransactionOutput data: \(value)")
        }
        
        let address = try Address.fromPrimitive(data: list[0] as! Data)
        let amount: Value = try Value.fromPrimitive(list[1])
        let datumHash: DatumHash = try DatumHash.fromPrimitive(list[2])
        
        return ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        ) as! T
    }
}
