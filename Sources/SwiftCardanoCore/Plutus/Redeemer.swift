import Foundation
import OrderedCollections
import CBORCodable

/// Redeemer tag, which indicates the type of redeemer.
public enum RedeemerTag: Int, Serializable {
    case spend = 0
    case mint = 1
    case cert = 2
    case reward = 3
    case voting = 4
    case proposing = 5

    public func description() -> String {
        switch self {
        case .spend: return "spend"
        case .mint: return "mint"
        case .cert: return "cert"
        case .reward: return "reward"
        case .voting: return "voting"
        case .proposing: return "proposing"
        }
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard let value = primitive.intValue,
            let tag = RedeemerTag(rawValue: value)
        else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerTag primitive: \(primitive)")
        }
        self = tag
    }

    public func toPrimitive() throws -> Primitive {
        return .int(Int64(rawValue))
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> RedeemerTag {
        // Support both formats: int or dict with "tag" key
        switch primitive {
        case .int(let value):
            guard let tag = RedeemerTag(rawValue: Int(value)) else {
                throw CardanoCoreError.deserializeError("Invalid RedeemerTag value: \(value)")
            }
            return tag
        case .orderedDict(let dict):
            guard let tagValue = dict[.string("tag")],
                case .int(let value) = tagValue,
                let tag = RedeemerTag(rawValue: Int(value))
            else {
                throw CardanoCoreError.deserializeError(
                    "Invalid RedeemerTag dictionary: \(primitive)")
            }
            return tag
        case .string(let str):
            // Also support string representation
            let mapping: [String: RedeemerTag] = [
                "spend": .spend, "mint": .mint, "cert": .cert,
                "reward": .reward, "voting": .voting, "proposing": .proposing,
            ]
            guard let tag = mapping[str] else {
                throw CardanoCoreError.deserializeError("Invalid RedeemerTag string: \(str)")
            }
            return tag
        default:
            throw CardanoCoreError.deserializeError("Invalid RedeemerTag: \(primitive)")
        }
    }

    public func toDict() throws -> Primitive {
        return .orderedDict([
            .string("tag"): .string(description()),
            .string("value"): .int(Int64(rawValue)),
        ])
    }
}

public enum RedeemerCodingKeys: String, CodingKey {
    case tag
    case index
    case data
    case exUnits
}

public protocol RedeemerProtocol: Serializable {
    var tag: RedeemerTag? { get set }
    var index: Int { get set }
    var data: PlutusData { get set }
    var exUnits: ExecutionUnits? { get set }

    init(tag: RedeemerTag?, index: Int, data: PlutusData, exUnits: ExecutionUnits?)
}

extension RedeemerProtocol {

    public static func == (lhs: Self, rhs: any RedeemerProtocol) -> Bool {
        return lhs.tag == rhs.tag && lhs.index == rhs.index && lhs.data == rhs.data
            && lhs.exUnits == rhs.exUnits
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 4
        else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer primitive")
        }

        let tag = try RedeemerTag(from: primitive[0])

        guard let index = primitive[1].intValue else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer index")
        }

        let exUnits = try ExecutionUnits(from: primitive[3])
        let data = try PlutusData.init(from: primitive[2])

        self.init(
            tag: tag,
            index: index,
            data: data,
            exUnits: exUnits
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try tag?.toPrimitive() ?? .null,
            .int(Int64(index)),
            try data.toPrimitive(),
            try exUnits?.toPrimitive() ?? .null,
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> Self {
        guard case .orderedDict(let dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Redeemer dict")
        }
        var tag: RedeemerTag? = nil
        if let tagPrimitive = dictValue[.string(RedeemerCodingKeys.tag.rawValue)] {
            tag = try RedeemerTag(from: tagPrimitive)
        }

        guard let indexPrimitive = dictValue[.string(RedeemerCodingKeys.index.rawValue)],
            case .int(let index) = indexPrimitive
        else {
            throw CardanoCoreError.deserializeError("Missing or invalid index in Redeemer dict")
        }

        guard let dataPrimitive = dictValue[.string(RedeemerCodingKeys.data.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing data in Redeemer dict")
        }
        let data: PlutusData
        if case .orderedDict = dataPrimitive {
            data = try PlutusData.fromDict(dataPrimitive)
        } else {
            data = try PlutusData(from: dataPrimitive)
        }

        var exUnits: ExecutionUnits? = nil
        if let exUnitsPrimitive = dictValue[.string(RedeemerCodingKeys.exUnits.rawValue)] {
            exUnits = try ExecutionUnits(from: exUnitsPrimitive)
        }

        return Self(
            tag: tag,
            index: Int(index),
            data: data,
            exUnits: exUnits
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedCollections.OrderedDictionary<Primitive, Primitive>()
        if let tag = tag {
            dict[.string(RedeemerCodingKeys.tag.rawValue)] = try tag.toPrimitive()
        }
        dict[.string(RedeemerCodingKeys.index.rawValue)] = .int(Int64(index))
        dict[.string(RedeemerCodingKeys.data.rawValue)] = try data.toDict()
        if let exUnits = exUnits {
            dict[.string(RedeemerCodingKeys.exUnits.rawValue)] = try exUnits.toPrimitive()
        }
        return .orderedDict(dict)
    }
}

public struct Redeemer: RedeemerProtocol {
    public var tag: RedeemerTag?
    public var index: Int = 0
    public var data: PlutusData
    public var exUnits: ExecutionUnits?

    public init(
        tag: RedeemerTag? = nil,
        index: Int = 0,
        data: PlutusData,
        exUnits: ExecutionUnits? = nil
    ) {
        self.tag = tag
        self.index = index
        self.data = data
        self.exUnits = exUnits
    }
}

/// Represents a unique key for a Redeemer.
public struct RedeemerKey: Serializable {
    public var tag: RedeemerTag
    public var index: Int = 0

    public init(tag: RedeemerTag, index: Int = 0) {
        self.tag = tag
        self.index = index
    }

    // Codable goes through `toPrimitive()` / `init(from primitive:)` — the
    // hand-written unkeyed-container versions encoded the tag as a nested
    // map instead of the integer the ledger expects, so `toCBORData()`
    // disagreed with the primitive encoding used everywhere else.

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(index)
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 2
        else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerKey primitive")
        }
        let index: Int
        switch primitive[1] {
        case .int(let v): index = Int(v)
        case .uint(let v): index = Int(v)
        default: throw CardanoCoreError.deserializeError("Invalid RedeemerKey primitive")
        }
        let tag = try RedeemerTag(from: primitive[0])
        self.tag = tag
        self.index = index
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try tag.toPrimitive(),
            .int(Int64(index)),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> RedeemerKey {
        guard case .list(let elements) = primitive,
            elements.count == 2,
            case .int(let index) = elements[1]
        else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerKey dict: \(primitive)")
        }

        let tag = try RedeemerTag.fromDict(elements[0])
        return RedeemerKey(tag: tag, index: Int(index))
    }

    public func toDict() throws -> Primitive {
        return .list([
            try tag.toDict(),
            .int(Int64(index)),
        ])
    }
}

/// Represents the value of a Redeemer, including data and execution units.
public struct RedeemerValue: Serializable {
    public var data: PlutusData
    public var exUnits: ExecutionUnits

    public init(data: PlutusData, exUnits: ExecutionUnits) {
        self.data = data
        self.exUnits = exUnits
    }

    // Codable goes through `toPrimitive()` / `init(from primitive:)`.

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 2
        else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerValue primitive")
        }

        let data = try PlutusData.init(from: primitive[0])
        let exUnits = try ExecutionUnits(from: primitive[1])

        self.data = data
        self.exUnits = exUnits
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try data.toPrimitive(),
            try exUnits.toPrimitive(),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> RedeemerValue {
        guard case .list(let elements) = primitive,
            elements.count == 2
        else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerValue dict: \(primitive)")
        }

        let data = try PlutusData(from: elements[0])
        let exUnits = try ExecutionUnits.fromDict(elements[1])
        return RedeemerValue(data: data, exUnits: exUnits)
    }

    public func toDict() throws -> Primitive {
        return .list([
            try data.toDict(),
            try exUnits.toDict(),
        ])
    }
}

/// Represents a mapping of RedeemerKeys to RedeemerValues.
///
/// Backed by an `OrderedDictionary` so that the entry order a transaction was
/// decoded with survives a re-encode. The Conway redeemers field is a CBOR map,
/// and `script_data_hash` is computed over its *exact* bytes — iterating a
/// Swift `Dictionary` here would re-emit the entries in an arbitrary order and
/// produce a hash that does not match the transaction being validated.
public struct RedeemerMap: Serializable {
    private var storage: OrderedDictionary<RedeemerKey, RedeemerValue>

    public init() {
        self.storage = [:]
    }

    public init(_ map: OrderedDictionary<RedeemerKey, RedeemerValue>) {
        self.storage = map
    }

    /// Builds a map from an unordered dictionary.
    ///
    /// Swift's `Dictionary` has no order to preserve, so the entries are laid
    /// out in canonical order (bytewise on the encoded key) to keep the result
    /// reproducible across processes.
    public init(_ map: [RedeemerKey: RedeemerValue]) {
        self.storage = Self.canonicallyOrdered(map.map { ($0.key, $0.value) })
    }

    public init(uniqueKeysWithValues elements: [(RedeemerKey, RedeemerValue)]) {
        self.storage = [:]
        for (key, value) in elements {
            storage[key] = value
        }
    }

    /// Orders key/value pairs by the bytewise encoding of their keys.
    private static func canonicallyOrdered(
        _ pairs: [(RedeemerKey, RedeemerValue)]
    ) -> OrderedDictionary<RedeemerKey, RedeemerValue> {
        let sorted = (try? pairs.sorted {
            try $0.0.toCBORData().lexicographicallyPrecedes($1.0.toCBORData())
        }) ?? pairs
        var result = OrderedDictionary<RedeemerKey, RedeemerValue>()
        for (key, value) in sorted {
            result[key] = value
        }
        return result
    }

    public subscript(key: RedeemerKey) -> RedeemerValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    /// The entries in their preserved order.
    public var dictionary: OrderedDictionary<RedeemerKey, RedeemerValue> {
        return storage
    }

    /// The entries as `(key, value)` pairs, in their preserved order.
    public var pairs: [(key: RedeemerKey, value: RedeemerValue)] {
        return storage.map { (key: $0.key, value: $0.value) }
    }

    public var isEmpty: Bool {
        return storage.isEmpty
    }

    public var count: Int {
        return storage.count
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let cborMap = CBOR.map(
            OrderedDictionary(
                uniqueKeysWithValues: try storage.map { (key, value) in
                    let cborKey = try key.toCBORData().toCBOR
                    let cborValue = try value.toCBORData().toCBOR
                    return (cborKey, cborValue)
                })
        )
        try container.encode(cborMap)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cbor = try container.decode(CBOR.self)
        guard case .map(let cborMap) = cbor else {
            throw CardanoCoreError.deserializeError("Invalid RedeemerMap type")
        }

        storage = [:]
        for (key, value) in cborMap {
            let keyData = try CBORSerialization.data(from: key)
            let valueData = try CBORSerialization.data(from: value)
            let redeemerKey = try RedeemerKey.fromCBOR(data: keyData)
            let redeemerValue = try RedeemerValue.fromCBOR(data: valueData)
            storage[redeemerKey] = redeemerValue
        }
    }

    /// Hashes the entries order-independently, matching ``==``.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage.count)
        var combined = 0
        for (key, value) in storage {
            var elementHasher = Hasher()
            elementHasher.combine(key)
            elementHasher.combine(value)
            combined ^= elementHasher.finalize()
        }
        hasher.combine(combined)
    }

    /// Two maps are equal when they hold the same entries, regardless of order.
    public static func == (lhs: RedeemerMap, rhs: RedeemerMap) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return lhs.storage.allSatisfy { rhs.storage[$0.key] == $0.value }
    }

    public init(from primitive: Primitive) throws {
        let pairs: [(Primitive, Primitive)]

        switch primitive {
        case .dict(let dict):
            // Unordered source — fall back to canonical key order below.
            pairs = dict.map { ($0.key, $0.value) }
        case .orderedDict(let orderedDict):
            pairs = orderedDict.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid RedeemerMap primitive: \(primitive)")
        }

        let decoded = try pairs.map { (keyPrimitive, valuePrimitive) in
            (try RedeemerKey(from: keyPrimitive), try RedeemerValue(from: valuePrimitive))
        }

        if case .dict = primitive {
            storage = Self.canonicallyOrdered(decoded)
        } else {
            storage = [:]
            for (key, value) in decoded {
                storage[key] = value
            }
        }
    }

    public func toPrimitive() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        for (key, value) in storage {
            dict[try key.toPrimitive()] = try value.toPrimitive()
        }

        return .orderedDict(dict)
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> RedeemerMap {
        let pairs: [(Primitive, Primitive)]

        switch primitive {
        case .dict(let dict):
            pairs = dict.map { ($0.key, $0.value) }
        case .orderedDict(let orderedDict):
            pairs = orderedDict.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid RedeemerMap dict: \(primitive)")
        }

        let decoded = try pairs.map { (keyPrimitive, valuePrimitive) in
            (try RedeemerKey.fromDict(keyPrimitive), try RedeemerValue.fromDict(valuePrimitive))
        }

        if case .dict = primitive {
            return RedeemerMap(Self.canonicallyOrdered(decoded))
        }

        var storage = OrderedDictionary<RedeemerKey, RedeemerValue>()
        for (key, value) in decoded {
            storage[key] = value
        }
        return RedeemerMap(storage)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        for (key, value) in storage {
            let keyPrimitive = try key.toDict()
            let valuePrimitive = try value.toDict()
            // For JSON, convert array keys to strings
            let keyString = "[\(try keyPrimitive.toJSON())]"
            dict[.string(keyString)] = valuePrimitive
        }

        return .orderedDict(dict)
    }
}

/// Redeemers can be a list of Redeemer objects or a map of Redeemer keys to values.
public enum Redeemers: Serializable {
    case list([any RedeemerProtocol])
    case map(RedeemerMap)

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .list(let list):
            var redeemers: [Redeemer] = []
            for item in list {
                let redeemer = try Redeemer(from: item)
                redeemers.append(redeemer)
            }
            self = .list(redeemers)

        case .dict(_):
            let redeemerMap = try RedeemerMap(from: primitive)
            self = .map(redeemerMap)

        case .orderedDict(_):
            let redeemerMap = try RedeemerMap(from: primitive)
            self = .map(redeemerMap)

        default:
            throw CardanoCoreError.deserializeError("Invalid Redeemers primitive")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .list(let redeemers):
            return .list(try redeemers.map { try $0.toPrimitive() })
        case .map(let redeemerMap):
            return try redeemerMap.toPrimitive()
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> Redeemers {
        switch primitive {
        case .list(let list):
            var redeemers: [Redeemer] = []
            for item in list {
                let redeemer = try Redeemer.fromDict(item)
                redeemers.append(redeemer)
            }
            return .list(redeemers)

        case .dict(_), .orderedDict(_):
            let redeemerMap = try RedeemerMap.fromDict(primitive)
            return .map(redeemerMap)

        default:
            throw CardanoCoreError.deserializeError("Invalid Redeemers dict: \(primitive)")
        }
    }

    public func toDict() throws -> Primitive {
        switch self {
        case .list(let redeemers):
            return .list(try redeemers.map { try $0.toDict() })
        case .map(let redeemerMap):
            return try redeemerMap.toDict()
        }
    }

    // MARK: - Equatable

    public static func == (lhs: Redeemers, rhs: Redeemers) -> Bool {
        switch (lhs, rhs) {
        case (.list(let lhsList), .list(let rhsList)):
            guard lhsList.count == rhsList.count else { return false }
            for (l, r) in zip(lhsList, rhsList) {
                // Compare by properties available on the protocol
                if l.tag?.rawValue != r.tag?.rawValue { return false }
                if l.index != r.index { return false }
                if l.exUnits != r.exUnits { return false }
                // Compare data via its Serializable equality semantics; fallback to primitive representation
                if l.data != r.data {
                    // As a safety, compare by primitive if direct equality differs in semantics
                    let lPrim = try? l.data.toPrimitive()
                    let rPrim = try? r.data.toPrimitive()
                    if String(describing: lPrim) != String(describing: rPrim) { return false }
                }
            }
            return true
        case (.map(let lhsMap), .map(let rhsMap)):
            return lhsMap == rhsMap
        default:
            return false
        }
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .list(let redeemers):
            hasher.combine(0)  // tag for list case
            hasher.combine(redeemers.count)
            // Hash each element using its primitive representation to avoid protocol existential hashing issues
            for r in redeemers {
                // Best-effort: hash by CBOR primitive if available; fall back to index
                if let primitive = try? r.toPrimitive() {
                    hasher.combine(String(describing: primitive))
                } else if let dict = try? r.toDict() {
                    hasher.combine(String(describing: dict))
                }
            }
        case .map(let map):
            hasher.combine(1)  // tag for map case
            hasher.combine(map)
        }
    }

}
