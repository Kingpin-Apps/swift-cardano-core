import Foundation

class MultiAsset: DictCBORSerializable {
    typealias KEY_TYPE = ScriptHash
    typealias VALUE_TYPE = Asset

    func union(_ other: MultiAsset) -> MultiAsset {
        return self + other
    }

    static func + (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            newMultiAsset
                .data[key] = (newMultiAsset.data[key] as! VALUE_TYPE) + (value as! VALUE_TYPE)
        }
        return newMultiAsset
    }

    static func += (lhs: inout MultiAsset, rhs: MultiAsset) {
        lhs = lhs + rhs
    }

    static func - (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            newMultiAsset
                .data[key] = (newMultiAsset.data[key] as! VALUE_TYPE) - (value as! VALUE_TYPE)
        }
        return newMultiAsset
    }

    static func == (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        return lhs.data as! [KEY_TYPE: VALUE_TYPE] == rhs.data as! [KEY_TYPE: VALUE_TYPE]
    }

    static func <= (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            if (rhs.data[key] as! VALUE_TYPE) < (value as! VALUE_TYPE) {
                return false
            }
        }
        return true
    }
    
    /// Filter items by criteria.
    /// - Parameter criteria: A function that takes in three input arguments (policy_id, asset_name, amount) and returns a bool. If returned value is True, then the asset will be kept, otherwise discarded.
    /// - Returns: A new filtered MultiAsset object.
    func filter(criteria: (ScriptHash, AssetName, Int) -> Bool) throws -> MultiAsset {
        var newMultiAsset = try! MultiAsset([:])
        
        guard let data = data as? [KEY_TYPE: VALUE_TYPE] else {
            throw CardanoCoreError.valueError("Invalid data type for MultiAsset")
        }
            
        for (policyId, asset) in data {
            for (assetName, amount) in asset.data {
                if criteria(
                    policyId,
                    assetName as! AssetName,
                    amount as! Int
                ) {
                    if newMultiAsset.data[policyId] == nil {
                        newMultiAsset.data[policyId] = try! Asset([:])
                    }
                    (newMultiAsset.data[policyId] as! Asset).data[assetName] = amount
                }
            }
        }
        return newMultiAsset
    }

    func count(criteria: (ScriptHash, AssetName, Int) -> Bool) throws -> Int {
        guard let data = data as? [KEY_TYPE: VALUE_TYPE] else {
            throw CardanoCoreError.valueError("Invalid data type for MultiAsset")
        }
        
        var count = 0
        for (policyId, asset) in data {
            for (assetName, amount) in asset.data {
                if criteria(
                    policyId,
                    assetName as! AssetName,
                    amount as! Int) {
                    count += 1
                }
            }
        }
        return count
    }
}
