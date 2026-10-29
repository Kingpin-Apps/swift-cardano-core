import Foundation
@preconcurrency import BigInt

/// An amount of ADA and of other assets: an output's value, or a sum or
/// difference of values.
///
/// Amounts are `BigInt`, as the ledger's `Coin` and asset quantities are
/// `Integer` (`MaryValue`, `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`):
/// an output may hold up to 2^64 − 1 lovelace and 2^64 − 1 of each asset, and
/// adding or subtracting values never overflows. Decoding refuses what the
/// ledger refuses; ``TransactionOutput/validate()`` checks an output's
/// amounts.
public struct Value: CBORSerializable, Comparable, Sendable {
    
    /// Amount of ADA, in lovelace.
    public var coin: BigInt

    /// Multi-assets associated with the UTx
    public var multiAsset: MultiAsset

    enum CodingKeys: CodingKey {
        case coin
        case multiAsset
    }

    public init(coin: BigInt = 0, multiAsset: MultiAsset = MultiAsset([:])) {
        self.coin = coin
        self.multiAsset = multiAsset
    }

    /// A value from a coin of any integer type.
    public init<T: BinaryInteger>(coin: T, multiAsset: MultiAsset = MultiAsset([:])) {
        self.init(coin: BigInt(coin), multiAsset: multiAsset)
    }

    public init(from list: [Any]) throws {
        guard list.count == 2 else {
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        let multiAsset: MultiAsset
        if let dict = list[1] as? [String: [String: Int64]] {
            multiAsset = try MultiAsset(from: dict)
        } else if let dict = list[1] as? [String: [String: Int]] {
            multiAsset = try MultiAsset(from: dict)
        } else if let dict = list[1] as? [String: [String: UInt64]] {
            multiAsset = try MultiAsset(from: dict)
        } else if let dict = list[1] as? [String: [String: BigInt]] {
            multiAsset = try MultiAsset(from: dict)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        let coinValue: BigInt
        switch list[0] {
        case let v as BigInt: coinValue = v
        case let v as Int64: coinValue = BigInt(v)
        case let v as Int: coinValue = BigInt(v)
        case let v as UInt64: coinValue = BigInt(v)
        default:
            throw CardanoCoreError.invalidArgument("Invalid Value data: \(list)")
        }
        self.coin = coinValue
        self.multiAsset = multiAsset
    }

    /// Reads the coin of an output as the ledger does: an unsigned 64-bit
    /// integer, 0 to 2^64 − 1 (`decodeWord64` in `decodeMaryValue`,
    /// `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`; `CompactForm Coin`
    /// before Mary).
    static func coin(from primitive: Primitive) throws -> BigInt {
        guard let value = primitive.integerValue else {
            throw CardanoCoreError.deserializeError("Invalid Value coin: \(primitive)")
        }
        guard UInt64(exactly: value) != nil else {
            throw CardanoCoreError.deserializeError("Value coin \(value) is outside 0 to 2^64 − 1")
        }
        return value
    }

    /// The JSON form an output gives its amount: the coin alone as a number,
    /// or `{"coin": …, "multiAsset": …}` when it holds tokens.
    func outputAmountDict() throws -> Primitive {
        guard !multiAsset.isEmpty else { return .integer(coin) }
        return .orderedDict([.string("coin"): .integer(coin), .string("multiAsset"): try multiAsset.toDict()])
    }

    /// Reads an output's amount from ``outputAmountDict()``'s JSON form.
    static func fromOutputAmountDict(_ primitive: Primitive) throws -> Value {
        if case .orderedDict(let amount) = primitive {
            guard let coin = amount[.string("coin")] else {
                throw CardanoCoreError.deserializeError("Invalid output amount JSON: missing coin")
            }
            let multiAsset = try amount[.string("multiAsset")].map { try MultiAsset.fromDict($0) }
            return Value(coin: try Value.coin(from: coin), multiAsset: multiAsset ?? MultiAsset([:]))
        }
        if case .string(let text) = primitive, let value = BigInt(text) {
            return Value(coin: try Value.coin(from: .bigInt(value)))
        }
        return Value(coin: try Value.coin(from: primitive))
    }

    /// Reads the value of an output as the ledger of the era decoding follows
    /// does (``Era/decoding``):
    ///
    /// - before Mary, a coin only (`ShelleyTxOut` holds a `Coin`);
    /// - from Mary, a coin or `[coin, multiasset<positive_coin>]`
    ///   (`decodeMaryValue`), the asset amounts 0 to 2^64 − 1, zeros dropped
    ///   before Conway and refused from it (`decodeMultiAsset`).
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .uint, .int, .bigInt, .bigUInt:
                self.coin = try Value.coin(from: primitive)
                self.multiAsset = MultiAsset([:])
            case .list, .indefiniteList:
                let listValue: [Primitive]
                if case .list(let elements) = primitive {
                    listValue = elements
                } else if case .indefiniteList(let elements) = primitive {
                    listValue = elements.getAll()
                } else {
                    listValue = []
                }
                guard Era.decodingRules >= .mary else {
                    throw CardanoCoreError.deserializeError(
                        "Value: an output holds only a coin before Mary, got \(primitive)")
                }
                guard listValue.count == 2 else {
                    throw CardanoCoreError.deserializeError("Invalid Value data: \(primitive)")
                }

                self.coin = try Value.coin(from: listValue[0])
                self.multiAsset = try MultiAsset(from: listValue[1], amounts: .output)
            default:
                throw CardanoCoreError.deserializeError("Invalid Value type")
        }
    }

    public func toPrimitive() -> Primitive {
        if multiAsset.isEmpty {
            return .integer(coin)
        }

        return .list([
            .integer(coin),
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
            coin: lhs.coin + BigInt(rhs),
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
            coin: lhs.coin - BigInt(rhs),
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
            let coin = try container.decode(JSONAmount.self, forKey: .coin).value
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
            
            try container.encode(JSONAmount(coin), forKey: .coin)
            
            if !multiAsset.isEmpty {
                try container.encodeIfPresent(multiAsset, forKey: .multiAsset)
            }
        } else  {
            var container = encoder.singleValueContainer()
            try container.encode(toPrimitive())
        }
    }
}

