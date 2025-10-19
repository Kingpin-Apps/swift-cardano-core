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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyTransactionOutput primitive")
        }
        
        guard elements.count >= 2 else {
            throw CardanoCoreError.deserializeError("ShelleyTransactionOutput requires at least 2 elements")
        }
        
        // address (Address)
        self.address = try Address(from: elements[0])
        
        // amount (Value)
        self.amount = try Value(from: elements[1])
        
        // datumHash (DatumHash?) - optional third element
        if elements.count > 2 {
            if case .null = elements[2] {
                self.datumHash = nil
            } else {
                self.datumHash = try DatumHash(from: elements[2])
            }
        } else {
            self.datumHash = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        
        // address (Address)
        elements.append(address.toPrimitive())
        
        // amount (Value)
        elements.append(amount.toPrimitive())
        
        // datumHash (DatumHash?) - include only if present
        if let datumHash = datumHash {
            elements.append(datumHash.toPrimitive())
        }
        
        return .list(elements)
    }
}
