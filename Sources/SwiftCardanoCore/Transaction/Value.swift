import Foundation

public struct Value: CBORSerializable, Equatable, Hashable {
    
    /// Amount of ADA
    public var coin: Int
    
    /// Multi-assets associated with the UTx
    public var multiAsset: MultiAsset
    
    public init(coin: Int = 0, multiAsset: MultiAsset = MultiAsset([:])) {
        self.coin = coin
        self.multiAsset = multiAsset
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        coin = try container.decode(Int.self)
        multiAsset = try container.decode(MultiAsset.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(coin)
        try container.encode(multiAsset)
    }
    
    public init(from primitive: Any) throws {
        guard let list = primitive as? [Any], list.count == 2 else {
            throw CardanoCoreError
                .decodingError("Invalid Value data: \(primitive)")
        }
        
        coin = list[0] as! Int
        multiAsset = try MultiAsset(from: list[1] as! [String: [String: Int]])
    }

    public func union(_ other: Value) -> Value {
        return self + other
    }

    public static func + (lhs: Value, rhs: Value) -> Value {
        return Value(
            coin: lhs.coin + rhs.coin,
            multiAsset: lhs.multiAsset + rhs.multiAsset
        )
    }

    public static func += (lhs: inout Value, rhs: Value) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Value, rhs: Value) {
        lhs = lhs - rhs
    }

    public static func - (lhs: Value, rhs: Value) -> Value {
        return Value(coin: lhs.coin - rhs.coin, multiAsset: lhs.multiAsset - rhs.multiAsset)
    }

    public static func == (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin == rhs.coin && lhs.multiAsset == rhs.multiAsset
    }

    public static func <= (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin <= rhs.coin && lhs.multiAsset <= rhs.multiAsset
    }

    public static func < (lhs: Value, rhs: Value) -> Bool {
        return lhs <= rhs && lhs != rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coin)
        hasher.combine(multiAsset)
    }
}
