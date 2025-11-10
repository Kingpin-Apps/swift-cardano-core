import Foundation
import OrderedCollections

/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
public struct Withdrawals: Serializable {
    public var data: OrderedDictionary<RewardAccount, Coin> {
        get { _data }
        set { _data = newValue }
    }
    private var _data: OrderedDictionary<RewardAccount, Coin> = [:]
    
    public init(_ data: OrderedDictionary<RewardAccount, Coin>) {
        self._data = data
    }
    
    // Subscript for easier key-value access
    public subscript(key: RewardAccount) -> Coin? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        self._data = [:]
        
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid Withdrawals type: \(primitive)")
        }
        
        for (key, value) in primitiveDict {
            guard case let .bytes(keyValue) = key,
                  case let .uint(intValue) = value else {
                throw CardanoCoreError.deserializeError("Invalid Withdrawals type: \(primitiveDict)")
            }
            self._data[RewardAccount(keyValue)] = Coin(intValue)
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var result: OrderedDictionary<Primitive, Primitive> = [:]
        for (key, value) in _data {
            result[.bytes(key)] = .uint(UInt(value))
        }
        return .orderedDict(result)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Withdrawals {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Withdrawals dict")
        }
        var data: OrderedDictionary<RewardAccount, Coin> = [:]
        for (key, value) in dictValue {
            guard case let .string(keyHex) = key,
                  case let .int(intValue) = value else {
                throw CardanoCoreError.deserializeError("Invalid Withdrawals dict")
            }
            let keyData = Data(hex: keyHex)
            data[RewardAccount(keyData)] = Coin(intValue)
        }
        return Withdrawals(data)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in _data {
            dict[.string(key.toHexString())] = .int(Int(value))
        }
        return .orderedDict(dict)
    }

}
