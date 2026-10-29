import Foundation
@preconcurrency import BigInt
import CBORCodable
import OrderedCollections

public struct MultiAsset: Serializable, Comparable {
    public var data: [ScriptHash: Asset] {
        get { _data }
        set { _data = newValue }
    }
    private var _data: [ScriptHash: Asset] = [:]
    
    // Subscript for easier key-value access
    public subscript(key: ScriptHash) -> Asset? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
    
    public var count: Int { data.count }
    
    public var isEmpty: Bool { data.isEmpty }
    
    public init(_ data: [ScriptHash: Asset]) {
        self._data = data
        self._data = self.normalizeData()
    }
    
    private func normalizeData() -> [ScriptHash: Asset] {
        var normalizedData: [ScriptHash: Asset] = [:]
        for (key, var value) in _data {
            value = value.normalize()
            if !value.isEmpty {
                normalizedData[key] = value
            }
        }
        return normalizedData
    }
    
    public init<T: BinaryInteger>(from dict: [String: [String: T]]) throws {
        var data: [ScriptHash: Asset] = [:]

        for (policyId, asset) in dict {
            let pid = ScriptHash(payload: policyId.hexStringToData)
            var assetData: OrderedDictionary<AssetName, BigInt> = [:]
            for (assetName, amount) in asset {
                let name = AssetName(from: assetName)
                assetData[name] = BigInt(amount)
            }
            data[pid] = Asset(assetData)
        }
        self.data = data
    }

    /// Reads a multi-asset with the amounts of the mint field, as the
    /// ledger's `DecCBOR MultiAsset` instance does (`decodeIntegerBounded64`,
    /// `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`).
    public init(from primitive: Primitive) throws {
        try self.init(from: primitive, amounts: .mint)
    }

    /// Reads a multi-asset whose amounts follow `amounts`, as
    /// `decodeMultiAsset` does (`eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`):
    ///
    /// - before Conway, zero amounts and then empty asset maps are dropped
    ///   (`decodeWithPrunning`);
    /// - from Conway, a zero amount or an empty asset map fails
    ///   (`decodeConway`);
    /// - in every era, the multi-asset must fit the ledger's compact form:
    ///   44 bytes an asset and 28 a policy, at most 65,535
    ///   (`isMultiAssetSmallEnough`).
    init(from primitive: Primitive, amounts: AssetAmountRule) throws {
        var data: [ScriptHash: Asset] = [:]
        
        let primitiveDict: OrderedDictionary<Primitive, Primitive>
        switch primitive {
            case let .dict(dict):
                primitiveDict = OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key, $0.value) })
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid MultiAsset type")
        }
        
        let refusesZeros = AssetAmountRule.refusesZeros
        for (policyId, asset) in primitiveDict {
            // policy_id = script_hash, a byte string. Read off the ledger's
            // bytes, a text key is rejected; a multi-asset built in code may
            // name its policies in hex.
            let isBytes: Bool
            if case .bytes = policyId { isBytes = true } else { isBytes = false }
            if Era.decoding != nil, !isBytes {
                throw CardanoCoreError.deserializeError("A policy id must be a byte string, got \(policyId)")
            }
            let pid = try ScriptHash(from: policyId)
            let assets = try Asset(from: asset, amounts: amounts)
            if assets.isEmpty {
                if refusesZeros {
                    throw CardanoCoreError.deserializeError("Empty Assets are not allowed")
                }
                data.removeValue(forKey: pid)
                continue
            }
            data[pid] = assets
        }
        let assetCount = data.values.reduce(0) { $0 + $1.count }
        guard 44 * assetCount + 28 * data.count <= 65535 else {
            throw CardanoCoreError.deserializeError("MultiAsset is too big to compact")
        }
        self.data = data
    }
    
    public func toPrimitive() -> Primitive {
        var primitives: OrderedDictionary<Primitive, Primitive> = [:]
        // Policies in canonical order (RFC 7049 §3.9, as CIP-21 asks of
        // transactions hardware wallets sign): policy ids are all 28 bytes,
        // so that is their byte order. The dictionary's own order is random.
        for policyId in data.keys.sorted(by: { $0.payload.lexicographicallyPrecedes($1.payload) }) {
            primitives[.bytes(policyId.payload)] = data[policyId]!.toPrimitive()
        }
        return .orderedDict(primitives)
    }
    
    public static func fromDict(_ primitive: Primitive) throws -> MultiAsset {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid MultiAsset dict type")
        }
        var data: [ScriptHash: Asset] = [:]
        for (policyId, asset) in dict {
            let pid = try ScriptHash(from: policyId)
            data[pid] = try Asset.fromDict(asset)
        }
        return MultiAsset(data)
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        for (policyId, asset) in data {
            dict[.string(policyId.payload.toHex)] = try asset.toDict()
        }
        return .orderedDict(dict)
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            
            let toEncode = data.reduce(into: [String: [String: JSONAmount]]()) { result, item in
                let (policyId, asset) = item
                let assetDict = asset.data.reduce(into: [String: JSONAmount]()) { res, assetItem in
                    let (assetName, amount) = assetItem
                    res[assetName.description] = JSONAmount(amount)
                }
                result[policyId.description] = assetDict
            }
            try container.encode(toEncode)
        } else  {
            var container = encoder.singleValueContainer()
            try container.encode(toPrimitive())
        }
    }

    public func union(_ other: MultiAsset) -> MultiAsset {
        return self + other
    }
    
    public func normalize() -> MultiAsset {
        var newMultiAsset = self
        for (key, var value) in data {
            value = value.normalize()
            if value.isEmpty {
                newMultiAsset.data.removeValue(forKey: key)
            } else {
                newMultiAsset.data[key] = value
            }
        }
        return newMultiAsset
    }

    public static func + (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            newMultiAsset
                .data[key] = (newMultiAsset.data[key] ?? Asset.zero) + value
        }
        return newMultiAsset.normalize()
    }

    public static func += (lhs: inout MultiAsset, rhs: MultiAsset) {
        lhs = lhs + rhs
    }

    public static func - (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            if let existingAsset = newMultiAsset.data[key] {
                newMultiAsset.data[key] = existingAsset - value
            } else {
                newMultiAsset.data[key] = Asset.zero - value
            }
        }
        
        return newMultiAsset.normalize()
    }

    public static func == (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        // Order-insensitive comparison: convert OrderedDictionary to Dictionary
        // This ensures CBOR and JSON deserialized values with different insertion orders are equal
        guard lhs.data.count == rhs.data.count else { return false }
        
        for (policyId, lhsAsset) in lhs.data {
            guard let rhsAsset = rhs.data[policyId] else { return false }
            
            // Compare assets for this policy (also order-insensitive)
            guard lhsAsset.data.count == rhsAsset.data.count else { return false }
            
            for (assetName, lhsAmount) in lhsAsset.data {
                guard let rhsAmount = rhsAsset.data[assetName], lhsAmount == rhsAmount else { return false }
            }
        }
        
        return true
    }

    public static func <= (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            guard let rhsData = rhs.data[key] else {
                // lhs has a policy ID that rhs doesn't have, so lhs cannot be <= rhs
                return false
            }
            if !(value <= rhsData) {
                return false
            }
        }
        return true
    }

    public static func >= (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            guard let rhsData = rhs.data[key] else {
                continue
            }
            if !(value >= rhsData) {
                return false
            }
        }
        return true
    }
    
    public static func < (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            guard let rhsData = rhs.data[key] else {
                continue
            }
            if !(value < rhsData) {
                return false
            }
        }
        return true
    }
    
    public static func > (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            guard let rhsData = rhs.data[key] else {
                continue
            }
            if !(value > rhsData) {
                return false
            }
        }
        return true
    }
    
    /// Filter items by criteria.
    /// - Parameter criteria: A function that takes in three input arguments (policy_id, asset_name, amount) and returns a bool. If returned value is True, then the asset will be kept, otherwise discarded.
    /// - Returns: A new filtered MultiAsset object.
    public func filter(criteria: (ScriptHash, AssetName, BigInt) -> Bool) throws -> MultiAsset {
        var newMultiAsset = MultiAsset([:])
            
        for (policyId, asset) in data {
            for (assetName, amount) in asset.data {
                if criteria(
                    policyId,
                    assetName,
                    amount
                ) {
                    // Create the asset if it doesn't exist
                    if newMultiAsset.data[policyId] == nil {
                        newMultiAsset.data[policyId] = Asset([:])
                    }
                    
                    // Safely access and update the asset using optional chaining instead of force unwrapping
                    if var assetObj = newMultiAsset.data[policyId] {
                        assetObj.data[assetName] = amount
                        newMultiAsset.data[policyId] = assetObj
                    }
                }
            }
        }
        return newMultiAsset
    }

    public func count(criteria: (ScriptHash, AssetName, BigInt) -> Bool) throws -> Int {
        var count = 0
        for (policyId, asset) in data {
            for (assetName, amount) in asset.data {
                if criteria(
                    policyId,
                    assetName,
                    amount
                ) {
                    count += 1
                }
            }
        }
        return count
    }
}

/// An amount in JSON: a number while it fits a 64-bit integer, signed or
/// unsigned, which every amount the ledger accepts in an output or the mint
/// field does; a decimal string beyond, which only a sum or difference can be.
struct JSONAmount: Codable, Sendable {
    let value: BigInt

    init(_ value: BigInt) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let signed = try? container.decode(Int64.self) {
            value = BigInt(signed)
        } else if let unsigned = try? container.decode(UInt64.self) {
            value = BigInt(unsigned)
        } else if let text = try? container.decode(String.self), let parsed = BigInt(text) {
            value = parsed
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid amount")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let signed = Int64(exactly: value) {
            try container.encode(signed)
        } else if let unsigned = UInt64(exactly: value) {
            try container.encode(unsigned)
        } else {
            try container.encode(value.description)
        }
    }
}
