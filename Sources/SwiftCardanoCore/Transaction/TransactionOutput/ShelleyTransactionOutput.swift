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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ShelleyTransactionOutput {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyTransactionOutput dict format")
        }
        guard case let .string(addressStr) = orderedDict[.string("address")] else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: missing address")
        }
        
        // Handle both int and uint for amount
        let amountValue: Int
        if case let .int(amountInt) = orderedDict[.string("amount")] {
            amountValue = amountInt
        } else if case let .uint(amountUInt) = orderedDict[.string("amount")] {
            amountValue = Int(amountUInt)
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: invalid amount")
        }
        
        let address = try Address(from: .string(addressStr))
        let amount = Value(coin: amountValue)
        
        var datumHash: DatumHash? = nil
        if case let .string(datumHashStr) = orderedDict[.string("datumHash")] {
            // When coming from JSON, the hash is base64-encoded
            if let data = Data(base64Encoded: datumHashStr) {
                datumHash = DatumHash(payload: data)
            } else {
                datumHash = try DatumHash(from: .bytes(datumHashStr.hexStringToData))
            }
        }
        
        return ShelleyTransactionOutput(
            address: address,
            amount: amount,
            datumHash: datumHash
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [
            .string("address"): .string(try address.toBech32()),
            .string("amount"): .uint(UInt(amount.coin))
        ]
        
        if let datumHash = datumHash {
            dict[.string("datumHash")] = .string(datumHash.payload.base64EncodedString())
        }
        
        return .orderedDict(dict)
    }
}
