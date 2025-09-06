import Foundation
import OrderedCollections

/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
public struct Withdrawals: Codable, Equatable, Hashable {
    public var data: OrderedDictionary<RewardAccount, Coin> {
        get { _data }
        set { _data = newValue }
    }
    private var _data: OrderedDictionary<RewardAccount, Coin> = [:]
    
    public init(_ data: OrderedDictionary<RewardAccount, Coin>) {
        self._data = data
    }
    
    public init(from primitive: Primitive) throws {
        self._data = [:]
        
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid Withdrawals type")
        }
        
        for (key, value) in primitiveDict {
            guard case let .bytes(keyValue) = key,
                  case let .int(intValue) = value else {
                throw CardanoCoreError.deserializeError("Invalid Withdrawals type")
            }
            self._data[RewardAccount(keyValue)] = Coin(intValue)
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var result: OrderedDictionary<Primitive, Primitive> = [:]
        for (key, value) in _data {
            result[.bytes(key)] = .int(Int(value))
        }
        return .orderedDict(result)
    }
    
    // Subscript for easier key-value access
    public subscript(key: RewardAccount) -> Coin? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
}
