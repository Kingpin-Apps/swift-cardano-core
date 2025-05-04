import Foundation
import PotentCBOR
import PotentCodables

public struct MultiAsset: CBORSerializable, Hashable, Equatable, Comparable {
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
        self.data = data
    }
    
    public init(from dict: [String: [String: Int]]) throws {
        var data: [ScriptHash: Asset] = [:]
        
        for (policyId, asset) in dict {
            let pid = ScriptHash(payload: policyId.hexStringToData)
            var assetData: [AssetName: Int] = [:]
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
        
        guard case let .dict(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid AssetName type")
        }
        
        for (policyId, asset) in primitive {
            guard case .string(_) = policyId  else {
                throw CardanoCoreError.deserializeError("Invalid MultiAsset type")
            }
            let pid = try ScriptHash(from: policyId)
            data[pid] = try Asset(from: asset)
        }
        self.data = data
    }
    
    public func toPrimitive() -> Primitive {
        var primitives: [Primitive: Primitive] = [:]
        for (policyId, asset) in data {
            let pid = policyId.payload.toHex
            primitives[.string(pid)] = asset.toPrimitive()
        }
        return .dict(primitives)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([ScriptHash: Asset].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }

    public func union(_ other: MultiAsset) -> MultiAsset {
        return self + other
    }
    
    public func normalize() -> MultiAsset {
        var newMultiAsset = self
        for var (key, value) in data {
            _ = value.normalize()
            if value.isEmpty {
                newMultiAsset.data.removeValue(forKey: key)
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
        // Clean up any assets that have all zero amounts
//        newMultiAsset.data = newMultiAsset.data.filter { (_, asset) in
//            !asset.data.values.allSatisfy { $0 == 0 }
//        }
        return newMultiAsset.normalize()
    }

    public static func == (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        return lhs.data == rhs.data
    }

    public static func <= (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            guard let rhsData = rhs.data[key] else {
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
                return false
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
                return false
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
                return false
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
                    assetName ,
                    amount
                ) {
                    if newMultiAsset.data[policyId] == nil {
                        newMultiAsset.data[policyId] = Asset([:])
                    }
                    (newMultiAsset.data[policyId]!).data[assetName] = amount
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
