import Foundation

public struct Value: CBORSerializable, Comparable, Sendable {
    
    /// Amount of ADA
    public var coin: Int64

    /// Multi-assets associated with the UTx
    public var multiAsset: MultiAsset

    enum CodingKeys: CodingKey {
        case coin
        case multiAsset
    }

    public init(coin: Int64 = 0, multiAsset: MultiAsset = MultiAsset([:])) {
        self.coin = coin
        self.multiAsset = multiAsset
    }

    public init(from list: [Any]) throws {
        guard list.count == 2,
              let dictValue = list[1] as? [String: [String: Int64]] else {
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        let coinValue: Int64
        if let v = list[0] as? Int64 {
            coinValue = v
        } else if let v = list[0] as? Int {
            coinValue = Int64(v)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        self.coin = coinValue
        self.multiAsset = try MultiAsset(from: dictValue)
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
            case .uint(let coinValue):
                self.coin = Int64(coinValue)
                self.multiAsset = MultiAsset([:])
            case .list(let listValue):
                guard listValue.count == 2 else {
                    throw CardanoCoreError.deserializeError("Invalid Value data: \(primitive)")
                }

                // Extract coin from first element which can be .int or .uint
                let coinPrimitive = listValue[0]
                let coinValue: Int64
                switch coinPrimitive {
                    case .int(let v):
                        coinValue = Int64(v)
                    case .uint(let v):
                        coinValue = Int64(v)
                    default:
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
            coin: lhs.coin + Int64(rhs),
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
            coin: lhs.coin - Int64(rhs),
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
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let coin = try container.decode(Int64.self, forKey: .coin)
            let multiAsset = try container.decodeIfPresent(MultiAsset.self, forKey: .multiAsset) ?? MultiAsset([:])
            self.init(coin: coin, multiAsset: multiAsset)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            try self.init(from: primitive)
        }
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(coin, forKey: .coin)
            
            if !multiAsset.isEmpty {
                try container.encodeIfPresent(multiAsset, forKey: .multiAsset)
            }
        } else  {
            var container = encoder.singleValueContainer()
            try container.encode(toPrimitive())
        }
    }
}

