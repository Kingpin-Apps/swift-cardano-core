import Foundation
import OrderedCollections


public struct ShelleyTransactionOutput: Serializable {
    let address: Address
    let amount: Value
    let datumHash: DatumHash?
    
    public init(address: Address, amount: Value, datumHash: DatumHash? = nil) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitiveValue: Primitive) throws {
        // The ledger reads the array with a definite or an indefinite length
        // (`decodeRecordNamed` in Shelley; `decodeListLenOrIndef` in the
        // Alonzo and Babbage decoders).
        let primitive: [Primitive]
        switch primitiveValue {
        case .list(let list): primitive = list
        case .indefiniteList(let list): primitive = list.getAll()
        default:
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy type")
        }
        
        // Shelley to Mary: `[address, amount]` (`decodeRecordNamed
        // "ShelleyTxOut" (const 2)`, `eras/shelley/impl/src/Cardano/Ledger/Shelley/TxOut.hs`).
        // From Alonzo a datum hash may follow (`DecCBOR AlonzoTxOut`,
        // `eras/alonzo/impl/src/Cardano/Ledger/Alonzo/TxOut.hs`).
        let maxCount = Era.decodingRules >= .alonzo ? 3 : 2
        guard (2...maxCount).contains(primitive.count) else {
            throw CardanoCoreError.deserializeError(
                "TransactionOutput: \(primitive.count) elements, expected 2\(maxCount == 3 ? " or 3" : "")")
        }
        self.address = try TransactionOutput.address(from: primitive[0])
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ShelleyTransactionOutput {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyTransactionOutput dict format")
        }
        guard case let .string(addressStr) = orderedDict[.string("address")] else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: missing address")
        }
        
        guard let amountPrimitive = orderedDict[.string("amount")] else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: missing amount")
        }
        let amount = try Value.fromOutputAmountDict(amountPrimitive)

        let address = try Address(from: .string(addressStr))
        
        var datumHash: DatumHash? = nil
        if let datumHashPrimitive = orderedDict[.string("datumHash")], datumHashPrimitive != .null {
            datumHash = try DatumHash(payload: datumHashPrimitive.jsonBytes("DatumHash", count: DatumHash.maxSize))
        }
        
        return ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [
            .string("address"): .string(try address.toText())
        ]
        
        dict[.string("amount")] = try amount.outputAmountDict()

        if let datumHash = datumHash {
            dict[.string("datumHash")] = .string(datumHash.payload.toHex)
        }
        
        return .orderedDict(dict)
    }
}
