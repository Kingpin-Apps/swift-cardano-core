import Foundation

public struct Value: CBORSerializable, Equatable, Hashable, Comparable {
    
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
    
    public init(from list: [Any]) throws {
        guard list.count == 2,
              let coinValue = list[0] as? Int,
              let dictValue = list[1] as? [String: [String: Int]] else {
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        self.coin = coinValue
        self.multiAsset = try MultiAsset(from: dictValue)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Value type")
        }
        
        guard primitive.count == 2,
          case let .int(coinValue) = primitive[0],
              case .dict(_) = primitive[1] else {
            throw CardanoCoreError.decodingError("Invalid Value data: \(primitive)")
        }
        
        self.coin = coinValue
        self.multiAsset = try MultiAsset(from: primitive[1])
    }
    
    public func toPrimitive() -> Primitive {
        return .list([
            .int(coin),
            multiAsset.toPrimitive()
        ])
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

    public static func >= (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin >= rhs.coin && lhs.multiAsset >= rhs.multiAsset
    }

    public static func < (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin < rhs.coin && lhs.multiAsset < rhs.multiAsset
    }

    public static func > (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin > rhs.coin && lhs.multiAsset > rhs.multiAsset
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coin)
        hasher.combine(multiAsset)
    }
}
