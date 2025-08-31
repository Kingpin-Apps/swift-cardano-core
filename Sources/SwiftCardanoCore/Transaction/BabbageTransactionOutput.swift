import Foundation

public struct BabbageTransactionOutput: CBORSerializable, Hashable, Equatable {
    public var address: Address
    public var amount: Value
    public var datum: DatumOption?
    public var scriptRef: ScriptRef?
    
    enum CodingKeys: Int, CodingKey {
        case address = 0
        case amount = 1
        case datum = 2
        case scriptRef = 3
    }
    
    public init(address: Address,
                amount: Value,
                datum: DatumOption? = nil,
                scriptRef: ScriptRef? = nil) {
        self.address = address
        self.amount = amount
        self.datum = datum
        self.scriptRef = scriptRef
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(Address.self, forKey: .address)
        amount = try container.decode(Value.self, forKey: .amount)
        datum = try container.decode(DatumOption.self, forKey: .datum)
        scriptRef = try container.decode(ScriptRef.self, forKey: .scriptRef)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(amount, forKey: .amount)
        try container.encode(datum, forKey: .datum)
        try container.encode(scriptRef, forKey: .scriptRef)
    }
    
    public var script: ScriptType? {
        return scriptRef?.script.script
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .dict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid BabbageTransactionOutput primitive")
        }
        
        // address (required)
        guard let addressPrimitive = dict[.int(0)] else {
            throw CardanoCoreError.deserializeError("Missing address in BabbageTransactionOutput")
        }
        self.address = try Address(from: addressPrimitive)
        
        // amount (required)
        guard let amountPrimitive = dict[.int(1)] else {
            throw CardanoCoreError.deserializeError("Missing amount in BabbageTransactionOutput")
        }
        self.amount = try Value(from: amountPrimitive)
        
        // datum (optional)
        if let datumPrimitive = dict[.int(2)] {
            if case .null = datumPrimitive {
                self.datum = nil
            } else {
                self.datum = try DatumOption(from: datumPrimitive)
            }
        } else {
            self.datum = nil
        }
        
        // scriptRef (optional)
        if let scriptRefPrimitive = dict[.int(3)] {
            if case .null = scriptRefPrimitive {
                self.scriptRef = nil
            } else {
                self.scriptRef = try ScriptRef(from: scriptRefPrimitive)
            }
        } else {
            self.scriptRef = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]
        
        // address (required)
        dict[.int(0)] = address.toPrimitive()
        
        // amount (required)
        dict[.int(1)] = amount.toPrimitive()
        
        // datum (optional)
        if let datum = datum {
            dict[.int(2)] = try datum.toPrimitive()
        }
        
        // scriptRef (optional)
        if let scriptRef = scriptRef {
            dict[.int(3)] = try scriptRef.toPrimitive()
        }
        
        return .dict(dict)
    }
}
