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
        
        // Handle amount: can be a simple int/uint (coin only) or a Value object (coin + multiAsset)
        let amount: Value
        if let amountPrimitive = orderedDict[.string("amount")] {
            switch amountPrimitive {
            case .int(let amountInt):
                // Simple coin-only value
                amount = Value(coin: amountInt)
            case .uint(let amountUInt):
                // Simple coin-only value
                amount = Value(coin: Int(amountUInt))
            case .orderedDict(let amountDict):
                // Complex Value with multiAsset - deserialize from {coin, multiAsset} format
                guard case let .int(coinValue) = amountDict[.string("coin")] else {
                    throw CardanoCoreError.deserializeError("Invalid Value format: missing coin")
                }
                let multiAsset: MultiAsset
                if let multiAssetPrimitive = amountDict[.string("multiAsset")] {
                    multiAsset = try MultiAsset.fromDict(multiAssetPrimitive)
                } else {
                    multiAsset = MultiAsset([:])
                }
                amount = Value(coin: coinValue, multiAsset: multiAsset)
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: invalid amount type")
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutputLegacy JSON format: missing amount")
        }
        
        let address = try Address(from: .string(addressStr))
        
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
            .string("address"): .string(try address.toBech32())
        ]
        
        // Serialize the full Value (including multiAsset if present)
        // to avoid data loss during JSON round-tripping
        if amount.multiAsset.isEmpty {
            // Simple case: just coin
            dict[.string("amount")] = .uint(UInt(amount.coin))
        } else {
            // Complex case: coin + multiAsset - serialize as array [coin, multiAsset]
            var amountDict = OrderedDictionary<Primitive, Primitive>()
            amountDict[.string("coin")] = .int(amount.coin)
            amountDict[.string("multiAsset")] = try amount.multiAsset.toDict()
            dict[.string("amount")] = .orderedDict(amountDict)
        }
        
        if let datumHash = datumHash {
            dict[.string("datumHash")] = .string(datumHash.payload.base64EncodedString())
        }
        
        return .orderedDict(dict)
    }
}
