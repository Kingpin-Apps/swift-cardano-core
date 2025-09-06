import Foundation

public struct Value: CBORSerializable, Equatable, Hashable, Comparable, Sendable {
    
    /// Amount of ADA
    public var coin: Int
    
    /// Multi-assets associated with the UTx
    public var multiAsset: MultiAsset
    
    public init(coin: Int = 0, multiAsset: MultiAsset = MultiAsset([:])) {
        self.coin = coin
        self.multiAsset = multiAsset
    }
    
//    public init(from decoder: Decoder) throws {
//        if let singleValueContainer = try? decoder.singleValueContainer() {
//            // Try to decode as a single coin value
//            if let coinValue = try? singleValueContainer.decode(Int.self) {
//                coin = coinValue
//                multiAsset = MultiAsset([:])
//                return
//            }
//        }
//        
//        // Decode as array format [coin, multiAsset]
//        var container = try decoder.unkeyedContainer()
//        coin = try container.decode(Int.self)
//        multiAsset = try container.decode(MultiAsset.self)
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        if multiAsset.isEmpty {
//            var container = encoder.singleValueContainer()
//            try container.encode(coin)
//        } else {
//            var container = encoder.unkeyedContainer()
//            try container.encode(coin)
//            try container.encode(multiAsset)
//        }
//    }
    
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
        switch primitive {
        case .int(let coinValue):
            self.coin = coinValue
            self.multiAsset = MultiAsset([:])
        case .list(let listValue):
            guard listValue.count == 2,
                case let .int(coinValue) = listValue[0] else {
                throw CardanoCoreError.deserializeError("Invalid Value data: \(primitive)")
            }
            self.coin = coinValue
            self.multiAsset = try MultiAsset(from: listValue[1])
        default:
            throw CardanoCoreError.deserializeError("Invalid Value type")
        }
    }
    
    public func toPrimitive() -> Primitive {
        if multiAsset.isEmpty {
            return .int(coin)
        }
        
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

    public static func + (lhs: Value, rhs: Coin) -> Value {
        return Value(
            coin: lhs.coin + Int(rhs),
            multiAsset: lhs.multiAsset
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
    
    public static func - (lhs: Value, rhs: Coin) -> Value {
        return Value(
            coin: lhs.coin - Int(rhs),
            multiAsset: lhs.multiAsset
        )
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
