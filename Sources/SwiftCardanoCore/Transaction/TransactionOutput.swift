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
        self.address = try Address(from: .string(address))
        self.amount = Value(coin: amount)
        
        if let datumHash = datumHash {
            self.datumHash = try DatumHash(from: .bytes(datumHash.hexStringToData))
        } else {
            self.datumHash = nil
        }
        
        self.datum = datum
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from primitives: Primitive) throws {
        if case .list(_) = primitives {
            let output = try TransactionOutputLegacy(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.datumHash = output.datumHash
        } else if case .dict(_) = primitives {
            let output = try TransactionOutputPostAlonzo(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.script = output.script
            let datum = output.datum?.datum ?? nil
            
            switch datum {
                case .datumHash(let hash):
                    self.datumHash = hash
                case .anyValue(let any):
                    self.datum = try Datum(from: any.toPrimitive())
                case .none:
                    self.datum = nil
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutput type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        if self.datum != nil || self.script != nil || self.postAlonzo {
            let datumOption: DatumOption?
            let scriptRef: ScriptRef?
            
            if let datumHash = self.datumHash {
                datumOption = DatumOption(datum: datumHash)
            } else if let datum = datum {
                datumOption = DatumOption(
                    datum: .anyValue(try datum.toPrimitive().toAnyValue())
                )
            } else {
                datumOption = nil
            }
            
            if let script = script {
                scriptRef = try ScriptRef(script: Script(script: script))
            } else {
                scriptRef = nil
            }
            
            return try TransactionOutputPostAlonzo(
                address: address,
                amount: amount,
                datum: datumOption,
                scriptRef: scriptRef
            ).toPrimitive()
        } else {
            return try TransactionOutputLegacy(
                address: address,
                amount: amount,
                datumHash: datumHash
            ).toPrimitive()
        }
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


public struct TransactionOutputPostAlonzo: CBORSerializable, Hashable, Equatable {
    let address: Address
    let amount: Value
    let datum: DatumOption?
    let scriptRef: ScriptRef?

    var script: ScriptType? {
        return scriptRef?.script.script
    }

    enum CodingKeys: Int, CodingKey {
        case address = 0
        case amount = 1
        case datum = 2
        case scriptRef = 3
    }
    
    public init(address: Address, amount: Value, datum: DatumOption? = nil, scriptRef: ScriptRef? = nil) {
        self.address = address
        self.amount = amount
        self.datum = datum
        self.scriptRef = scriptRef
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .dict(primitiveDict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }      
        
        guard primitiveDict.count >= 2 else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }
                
        
        self.address = try Address(from: primitiveDict[.int(0)]!)
        self.amount = try Value(from: primitiveDict[.int(1)]!)
        
        if let datum = primitiveDict[.int(2)] {
            self.datum = try DatumOption(from: datum)
        } else {
            self.datum = nil
        }
        
        if let scriptRef = primitiveDict[.int(3)] {
            self.scriptRef = try ScriptRef(from: scriptRef)
        } else {
            self.scriptRef = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .dict([
            .int(0): address.toPrimitive(),
            .int(1): amount.toPrimitive(),
            .int(2): try datum?.toPrimitive() ?? .null,
            .int(3): try scriptRef?.toPrimitive() ?? .null
        ])
    }
}


public struct TransactionOutputLegacy: CBORSerializable, Hashable, Equatable {
    let address: Address
    let amount: Value
    let datumHash: DatumHash?

    enum CodingKeys: CodingKey {
        case address
        case amount
        case datumHash
    }
    
    public init(address: Address, amount: Value, datumHash: DatumHash? = nil) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }
        
        self.address = try Address(from: primitive[0])
        self.amount = try Value(from: primitive[1])
        self.datumHash = try DatumHash(from: primitive[2])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            address.toPrimitive(),
            amount.toPrimitive(),
            datumHash?.toPrimitive() ?? .null
        ])
    }
}
