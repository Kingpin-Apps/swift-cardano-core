import Foundation
import PotentCodables
import OrderedCollections

public struct TransactionOutput: CBORSerializable, Hashable, Equatable {
    public var address: Address
    public var amount: Value
    public var datumHash: DatumHash?
    public var datumOption: DatumOption?
    public var script: ScriptType?
    public var postAlonzo: Bool = false

    public var lovelace: Int {
        return amount.coin
    }
    
    public init(
        address: Address,
        amount: Value,
        datumHash: DatumHash? = nil,
        datumOption: DatumOption? = nil,
        script: ScriptType? = nil,
        postAlonzo: Bool = false
    ) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
        self.datumOption = datumOption
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from
                address: String,
                amount: Int,
                datumHash: String? = nil,
                datumOption: DatumOption? = nil,
                script: ScriptType? = nil,
                postAlonzo: Bool = false
    ) throws {
        self.address = try Address(from: .string(address))
        self.amount = Value(coin: amount)
        
        if let datumHash = datumHash {
            self.datumHash = try DatumHash(from: .bytes(datumHash.hexStringToData))
        } else {
            self.datumHash = nil
        }
        
        self.datumOption = datumOption
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from primitives: Primitive) throws {
        if case .list(_) = primitives {
            let output = try TransactionOutputLegacy(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.datumHash = output.datumHash
            self.datumOption = nil
            self.script = nil
            self.postAlonzo = false  // Legacy format
        } else if case .orderedDict(_) = primitives {
            let output = try TransactionOutputPostAlonzo(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.script = output.script
            let datum = output.datumOption?.datum ?? nil
            
            switch datum {
                case .datumHash(let hash):
                    self.datumHash = hash
                    self.datumOption = nil
                case .data(let data):
                    self.datumHash = nil
                    self.datumOption = DatumOption(datum: data)
                case .none:
                    self.datumHash = nil
                    self.datumOption = nil
            }
            
            self.postAlonzo = true  // Post-Alonzo format
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutput type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        if self.datumOption != nil || self.script != nil || self.postAlonzo {
            let datumOption: DatumOption?
            let scriptRef: ScriptRef?
            
            if let datumHash = self.datumHash {
                datumOption = DatumOption(datum: datumHash)
            } else if let datum = self.datumOption {
                datumOption = datum
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
                datumOption: datumOption,
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
        lhs.datumOption == rhs.datumOption &&
        lhs.script == rhs.script &&
        lhs.postAlonzo == rhs.postAlonzo
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(amount)
        hasher.combine(datumHash)
        hasher.combine(datumOption)
        hasher.combine(script)
    }
}


public struct TransactionOutputPostAlonzo: CBORSerializable, Hashable, Equatable {
    let address: Address
    let amount: Value
    let datumOption: DatumOption?
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
    
    public init(
        address: Address,
        amount: Value,
        datumOption: DatumOption? = nil,
        scriptRef: ScriptRef? = nil
    ) {
        self.address = address
        self.amount = amount
        self.datumOption = datumOption
        self.scriptRef = scriptRef
    }
    
    public init(from primitive: Primitive) throws {
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }
        
        guard primitiveDict.count >= 2 else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }
                
        
        self.address = try Address(
            from: primitiveDict[.uint(UInt(CodingKeys.address.rawValue))]!
        )
        self.amount = try Value(
            from: primitiveDict[.uint(UInt(CodingKeys.amount.rawValue))]!
        )
        
        if let datum = primitiveDict[.uint(UInt(CodingKeys.datum.rawValue))] {
            self.datumOption = try DatumOption(from: datum)
        } else {
            self.datumOption = nil
        }
        
        if let scriptRef = primitiveDict[.uint(UInt(CodingKeys.scriptRef.rawValue))] {
            self.scriptRef = try ScriptRef(from: scriptRef)
        } else {
            self.scriptRef = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dict: Dictionary<Primitive, Primitive> = [
            .int(CodingKeys.address.rawValue): address.toPrimitive(),
            .int(CodingKeys.amount.rawValue): amount.toPrimitive()
        ]
        
        if datumOption != nil {
            dict[.uint(UInt(CodingKeys.datum.rawValue))] = try datumOption!
                .toPrimitive()
        }
        
        if scriptRef != nil {
            dict[.uint(UInt(CodingKeys.scriptRef.rawValue))] = try scriptRef!
                .toPrimitive()
        }
        
        return .dict(dict)
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
        
        if primitive.count > 2 {
            self.datumHash = try DatumHash(from: primitive[2])
        } else {
            self.datumHash = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var list: [Primitive] = [
            address.toPrimitive(),
            amount.toPrimitive()
        ]
        
        if let datumHash = datumHash {
            list.append(datumHash.toPrimitive())
        }
        
        return .list(list)
    }
}
