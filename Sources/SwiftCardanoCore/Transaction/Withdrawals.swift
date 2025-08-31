import Foundation

/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
public struct Withdrawals: Codable, Equatable, Hashable {
    public var data: [RewardAccount: Coin] {
        get { _data }
        set { _data = newValue }
    }
    private var _data: [RewardAccount: Coin] = [:]
    
    public init(_ data: [RewardAccount: Coin]) {
        self._data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _data = try container.decode([RewardAccount: Coin].self)
    }
    
    public init(from primitive: Primitive) throws {
        self._data = [:]
        
        guard case let .dict(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Withdrawals type")
        }
        
        for (key, value) in primitive {
            guard case let .bytes(keyValue) = key,
                  case let .int(intValue) = value else {
                throw CardanoCoreError.deserializeError("Invalid Withdrawals type")
            }
            self._data[RewardAccount(keyValue)] = Coin(intValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_data)
    }
    
    public func toPrimitive() throws -> Primitive {
        var result = [Primitive: Primitive]()
        for (key, value) in _data {
            result[.bytes(key)] = .int(Int(value))
        }
        return .dict(result)
    }
    
    // Subscript for easier key-value access
    public subscript(key: RewardAccount) -> Coin? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
}
