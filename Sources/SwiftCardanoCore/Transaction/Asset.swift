import Foundation
@preconcurrency import BigInt
import CBORCodable
import OrderedCollections


public struct AssetName: ConstrainedBytes, Hashable, Equatable, Sendable {
    public var payload: Data
    public static var maxSize: Int { 32 }
    public static var minSize: Int { 0 }

    public init(payload: Data) throws {
        self.payload = payload
    }

    public init(from name: String) {
        if !name.hexStringToData.isEmpty {
            self.payload = name.hexStringToData
        } else {
            self.payload = name.data(using: .utf8)!
        }
    }

    /// Reads an asset name as the ledger does: a byte string of at most 32
    /// bytes (`DecCBOR AssetName`, `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`).
    static func ledger(from primitive: Primitive) throws -> AssetName {
        guard case let .bytes(bytes) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid AssetName type: \(primitive)")
        }
        guard bytes.count <= maxSize else {
            throw CardanoCoreError.deserializeError(
                "AssetName: \(bytes.count) bytes, at most \(maxSize) allowed")
        }
        return try AssetName(payload: bytes)
    }

    public var debugDescription: String {
        return "AssetName(\(self.payload.toString))"
    }

    public var description: String {
        return self.payload.toString
    }
}

/// The amounts the ledger accepts in a multi-asset, which depend on where it
/// is (`decodeMultiAsset`, `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`).
enum AssetAmountRule: Sendable {
    /// In an output, `multiasset<positive_coin>`: an unsigned 64-bit integer,
    /// 0 to 2^64 − 1 (`decodeMaryValue` reads them with `decodeWord64`).
    case output
    /// In the mint field, `multiasset<nonZeroInt64>`: a signed 64-bit
    /// integer (`decodeIntegerBounded64`, the `DecCBOR MultiAsset` instance).
    case mint

    /// Reads one amount. A zero is returned; the caller prunes or refuses it.
    func read(_ primitive: Primitive) throws -> BigInt {
        guard let value = primitive.integerValue else {
            throw CardanoCoreError.deserializeError("Invalid Asset amount type: \(primitive)")
        }
        switch self {
        case .output:
            guard UInt64(exactly: value) != nil else {
                throw CardanoCoreError.deserializeError(
                    "Asset amount \(value) in an output is outside 0 to 2^64 − 1")
            }
        case .mint:
            guard Int64(exactly: value) != nil else {
                throw CardanoCoreError.deserializeError(
                    "Asset amount \(value) in the mint field is outside the signed 64-bit range")
            }
        }
        return value
    }

    /// Whether a zero amount or an empty asset map fails rather than being
    /// dropped: from Conway (protocol version 9, `decodeConway` in
    /// `decodeMultiAsset`); before it the ledger prunes them
    /// (`decodeWithPrunning`, `pruneZeroMultiAsset`).
    static var refusesZeros: Bool { Era.decodingRules >= .conway }
}

/// The assets of one policy: asset name to amount.
///
/// Amounts are `BigInt`, as the ledger's are `Integer`: an output holds up to
/// 2^64 − 1 of an asset and the mint field −2^63 to 2^63 − 1, and sums and
/// differences of them never overflow. Decoding refuses what the ledger
/// refuses; ``TransactionOutput/validate()`` checks an output's amounts.
public struct Asset: Serializable, Comparable, AdditiveArithmetic {
    public static var zero: Asset {
        return Asset([:])
    }

    public var data: OrderedDictionary<AssetName, BigInt> {
        get { _data }
        set {
            _data = newValue
            _data = normalizeData(_data)
        }
    }
    private var _data: OrderedDictionary<AssetName, BigInt> = [:]

    public subscript(key: AssetName) -> BigInt? {
        get { return _data[key] }
        set {
            if let value = newValue, value != 0 {
                _data[key] = value
            } else {
                _data.removeValue(forKey: key)
            }
        }
    }

    public var isEmpty: Bool {
        return data.isEmpty
    }

    public var count: Int {
        return data.count
    }

    public init(_ data: OrderedDictionary<AssetName, BigInt>) {
        self.data = data
    }

    /// An asset map from amounts of any integer type.
    public init<T: BinaryInteger>(_ data: OrderedDictionary<AssetName, T>) {
        self.init(data.mapValues { BigInt($0) })
    }

    // MARK: - CBORSerializable

    /// Reads an asset map with the amounts the mint field holds, as the
    /// ledger's `DecCBOR MultiAsset` does (`decodeIntegerBounded64`).
    public init(from primitive: Primitive) throws {
        try self.init(from: primitive, amounts: .mint)
    }

    /// Reads an asset map whose amounts follow `amounts`.
    ///
    /// A zero amount is dropped before Conway and fails from it
    /// (``AssetAmountRule/refusesZeros``).
    init(from primitive: Primitive, amounts: AssetAmountRule) throws {
        self.data = [:]

        let primitiveDict: OrderedDictionary<Primitive, Primitive>
        switch primitive {
            case let .dict(dict):
                primitiveDict = OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key, $0.value) })
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid Asset type")
        }

        let refusesZeros = AssetAmountRule.refusesZeros
        for (key, value) in primitiveDict {
            let name = try AssetName.ledger(from: key)
            let amount = try amounts.read(value)
            if amount == 0 && refusesZeros {
                throw CardanoCoreError.deserializeError("MultiAsset cannot contain zeros")
            }
            self[name] = amount
        }
    }

    public func toPrimitive() -> Primitive {
        var result: OrderedDictionary<Primitive, Primitive> = [:]
        // Asset names in canonical order (RFC 7049 §3.9, as CIP-21 asks):
        // shorter names first, then by their bytes.
        let names = data.keys.sorted { a, b in
            a.payload.count != b.payload.count ? a.payload.count < b.payload.count : a.payload.lexicographicallyPrecedes(b.payload)
        }
        for name in names {
            result[name.toPrimitive()] = .integer(data[name]!)
        }
        return .orderedDict(result)
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> Asset {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Asset type")
        }
        var assetData: OrderedDictionary<AssetName, BigInt> = [:]
        for (key, value) in dict {
            let assetName: String
            switch key {
                case let .string(keyValue):
                    assetName = keyValue
                case let .bytes(dataValue):
                    assetName = dataValue.toHexString()
                default:
                    throw CardanoCoreError.deserializeError("Invalid AssetName type: \(key)")
            }
            guard let amount = value.integerValue ?? Self.integer(fromString: value) else {
                throw CardanoCoreError.deserializeError("Invalid Asset amount type: \(value)")
            }
            assetData[AssetName(from: assetName)] = amount
        }
        return Asset(assetData)
    }

    /// An amount written in JSON as a decimal string, as ``toDict()`` writes
    /// one outside the 64-bit ranges.
    static func integer(fromString primitive: Primitive) -> BigInt? {
        guard case let .string(text) = primitive else { return nil }
        return BigInt(text)
    }

    public func toDict() throws -> Primitive {
        var result: OrderedDictionary<Primitive, Primitive> = [:]
        for (key, value) in data {
            result[.string(key.payload.toHex)] = .integer(value)
        }
        return .orderedDict(result)
    }

    private func normalizeData(_ data: OrderedDictionary<AssetName, BigInt>) -> OrderedDictionary<AssetName, BigInt> {
        return data.filter { $0.value != 0 }
    }

    public mutating func normalize() -> Asset {
        _data = normalizeData(_data)
        return self
    }

    public func remove(_ key: AssetName) -> Asset {
        var result = self
        result.data.removeValue(forKey: key)
        return result
    }

    public func union(_ other: Asset) -> Asset {
        return self + other
    }

    public static func + (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) + value
        }
        return result
    }

    public static func - (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) - value
        }
        return result
    }

    public static func < (lhs: Asset, rhs: Asset) -> Bool {
        // lhs < rhs means lhs <= rhs && lhs != rhs
        return lhs <= rhs && lhs != rhs
    }

    public static func <= (lhs: Asset, rhs: Asset) -> Bool {
        // Check if lhs is a subset of rhs with all values <= corresponding rhs values
        for (key, value) in lhs.data {
            guard let rhsValue = rhs.data[key] else {
                // lhs has an asset that rhs doesn't have, so lhs cannot be <= rhs
                return false
            }
            if value > rhsValue {
                // lhs has more of this asset than rhs, so lhs cannot be <= rhs
                return false
            }
        }
        return true
    }

    public static func > (lhs: Asset, rhs: Asset) -> Bool {
        // lhs > rhs means rhs < lhs
        return rhs < lhs
    }

    public static func >= (lhs: Asset, rhs: Asset) -> Bool {
        // lhs >= rhs means rhs <= lhs
        return rhs <= lhs
    }
}
