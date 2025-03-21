import Foundation

public struct TransactionOutput: CBORSerializable, Hashable, Equatable {
    public var address: Address
    public var amount: Value
    public var datumHash: DatumHash?
    public var datum: Datum?
    public var script: ScriptType?
    public var postAlonzo: Bool = true

    public var lovelace: Int {
        return amount.coin
    }
    
    public init(address: Address, amount: Value, datumHash: DatumHash? = nil, datum: Datum? = nil, script: ScriptType? = nil, postAlonzo: Bool = true) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
        self.datum = datum
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from
                address: String,
                amount: Int,
                datumHash: String? = nil,
                datum: Datum? = nil,
                script: ScriptType? = nil,
                postAlonzo: Bool = true
    ) throws {
        self.address = try Address(from: address)
        self.amount = Value(coin: amount)
        self.datumHash = try datumHash.map { try DatumHash(from: $0) }
        self.datum = datum
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(
            keyedBy: BabbageTransactionOutput.CodingKeys.self
        ) {
            address = try keyedContainer.decode(Address.self, forKey: .address)
            amount = try keyedContainer.decode(Value.self, forKey: .amount)
            datum = try? keyedContainer.decode(Datum.self, forKey: .datum)
            let scriptRef = try? keyedContainer.decode(ScriptRef.self, forKey: .scriptRef)
            script = scriptRef?.script.script
        } else if var unkeyedContainer = try? decoder.unkeyedContainer() {
            address = try unkeyedContainer.decode(Address.self)
            amount = try unkeyedContainer.decode(Value.self)
            datumHash = try? unkeyedContainer.decode(DatumHash.self)
        } else {
            throw CardanoCoreError
                .decodingError("Invalid transaction output data")
        }
    }

    public func encode(to encoder: Encoder) throws {
        if postAlonzo {
            var keyedContainer = encoder.container(
                keyedBy: BabbageTransactionOutput.CodingKeys.self
            )
            try keyedContainer.encode(address, forKey: .address)
            try keyedContainer.encode(amount, forKey: .amount)
            try keyedContainer.encodeIfPresent(datum, forKey: .datum)
            try keyedContainer.encodeIfPresent(script, forKey: .scriptRef)
        } else {
            var unkeyedContainer = encoder.unkeyedContainer()
            try unkeyedContainer.encode(address)
            try unkeyedContainer.encode(amount)
            try unkeyedContainer.encode(datumHash)
        }
    }

    public func validate() throws {
        if amount.coin < 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of ADA: \(amount)")
        }
        if try amount.multiAsset.count(criteria: { _, _, v in v < 0 }) > 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of tokens or native assets: \(amount)")
        }
    }
    
    public static func == (lhs: TransactionOutput, rhs: TransactionOutput) -> Bool {
        return lhs.address == rhs.address &&
        lhs.amount == rhs.amount &&
        lhs.datumHash == rhs.datumHash &&
        lhs.datum == rhs.datum &&
        lhs.script == rhs.script &&
        lhs.postAlonzo == rhs.postAlonzo
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(amount)
        hasher.combine(datumHash)
        hasher.combine(datum)
        hasher.combine(script)
    }
}
