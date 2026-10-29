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

    /// Reads a decoded coin into the `Int64` that `Value` holds.
    ///
    /// A negative coin is kept, as `Value` also holds differences; an
    /// output's ``TransactionOutput/validate()`` rejects one.
    ///
    /// - Throws: When the value is not an integer or is outside `Int64`. The
    ///   total ADA supply is far below `Int64.max`, so no real amount is
    ///   refused.
    static func coin(from primitive: Primitive) throws -> Int64 {
        guard primitive.integerValue != nil else {
            throw CardanoCoreError.deserializeError("Invalid Value coin: \(primitive)")
        }
        return try primitive.integer("Value coin", as: Int64.self)
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
            case .uint, .int, .bigInt, .bigUInt:
                self.coin = try Value.coin(from: primitive)
                self.multiAsset = MultiAsset([:])
            case .list(let listValue):
                guard listValue.count == 2 else {
                    throw CardanoCoreError.deserializeError("Invalid Value data: \(primitive)")
                }

                self.coin = try Value.coin(from: listValue[0])
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
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
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

