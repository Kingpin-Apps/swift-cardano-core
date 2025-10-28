import Foundation
import PotentCBOR
import PotentCodables
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
    
    public init(from dict: [String: [String: Int]]) throws {
        var data: [ScriptHash: Asset] = [:]
        
        for (policyId, asset) in dict {
            let pid = ScriptHash(payload: policyId.hexStringToData)
            var assetData: OrderedDictionary<AssetName, Int> = [:]
            for (assetName, amount) in asset {
                let name = AssetName(from: assetName)
                assetData[name] = amount
            }
            data[pid] = Asset(assetData)
        }
        self.data = data
    }

        
    public init(from primitive: Primitive) throws {
        var data: [ScriptHash: Asset] = [:]
        
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid MultiAsset type")
        }
        
        for (policyId, asset) in primitiveDict {
            let pid = try ScriptHash(from: policyId)
            data[pid] = try Asset(from: asset)
        }
        self.data = data
    }
    
    public func toPrimitive() -> Primitive {
        var primitives: OrderedDictionary<Primitive, Primitive> = [:]
        
        for (policyId, asset) in data {
            primitives[.bytes(policyId.payload)] = asset.toPrimitive()
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
            
            let toEncode = data.reduce(into: [String: [String: Int]]()) { result, item in
                let (policyId, asset) = item
                let assetDict = asset.data.reduce(into: [String: Int]()) { res, assetItem in
                    let (assetName, amount) = assetItem
                    res[assetName.description] = amount
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
        return lhs.data == rhs.data
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
    public func filter(criteria: (ScriptHash, AssetName, Int) -> Bool) throws -> MultiAsset {
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

    public func count(criteria: (ScriptHash, AssetName, Int) -> Bool) throws -> Int {
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
