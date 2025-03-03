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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_data)
    }
    
    // Subscript for easier key-value access
    public subscript(key: RewardAccount) -> Coin? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
}
