import OrderedCollections


public struct TransactionOutputPostAlonzo: Serializable {
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: OrderedDictionary<Primitive, Primitive>) throws -> TransactionOutputPostAlonzo {
        guard case let .string(addressStr) = dict[.string("address")] else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputPostAlonzo JSON format")
        }
        
        // Handle both int and uint for amount
        let amountValue: Int
        if case let .int(amountInt) = dict[.string("amount")] {
            amountValue = amountInt
        } else if case let .uint(amountUInt) = dict[.string("amount")] {
            amountValue = Int(amountUInt)
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputPostAlonzo JSON format: invalid amount: \(String(describing: dict[.string("amount")]))")
        }
        
        let address = try Address(from: .string(addressStr))
        let amount = Value(coin: amountValue)
        
        var datumOption: DatumOption? = nil
        if case let .orderedDict(datumDict) = dict[.string("datum")] {
            datumOption = try DatumOption.fromDict(datumDict)
        }
        
        var scriptRef: ScriptRef? = nil
        if case let .orderedDict(scriptDict) = dict[.string("scriptRef")]  {
            scriptRef = try ScriptRef.fromDict(scriptDict)
        }
        
        return TransactionOutputPostAlonzo(
            address: address,
            amount: amount,
            datumOption: datumOption,
            scriptRef: scriptRef
        )
    }
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        var dict: OrderedDictionary<Primitive, Primitive> = [
            .string("address"): .string(try address.toBech32()),
            .string("amount"): .uint(UInt(amount.coin))
        ]
        if let datumOption = datumOption {
            dict[.string("datum")] = .orderedDict(try datumOption.toDict())
        }
        if let scriptRef = scriptRef {
            dict[.string("scriptRef")] = .orderedDict(try scriptRef.toDict())
        }
        return dict
    }
}
