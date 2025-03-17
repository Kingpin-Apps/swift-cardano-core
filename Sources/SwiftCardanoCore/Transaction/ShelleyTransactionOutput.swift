import Foundation

public struct ShelleyTransactionOutput: CBORSerializable, Equatable, Hashable {
    public var address: Address
    public var amount: Value
    public var datumHash: DatumHash?
    
    public init(address: Address, amount: Value, datumHash: DatumHash?) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        address = try container.decode(Address.self)
        amount = try container.decode(Value.self)
        datumHash = try container.decodeIfPresent(DatumHash.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(address)
        try container.encode(amount)
        try container.encode(datumHash)
    }
}
