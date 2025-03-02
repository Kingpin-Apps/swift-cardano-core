import Foundation
import PotentCBOR
import PotentCodables

public struct MultiAsset: Codable, Hashable, Equatable {
    var data: [ScriptHash: Asset] {
        get { _data }
        set { _data = newValue }
    }
    private var _data: [ScriptHash: Asset] = [:]
    
    // Subscript for easier key-value access
    public subscript(key: ScriptHash) -> Asset? {
        get { _data[key] }
        set { _data[key] = newValue }
    }
    
    public init(_ data: [AnyHashable: AnyHashable]) {
        self.data = data as! [ScriptHash: Asset]
    }
    
    public init(from primitive: [String: [String: Int]]) throws {
        var data: [ScriptHash: Asset] = [:]
        for (policyId, asset) in primitive {
            data[try ScriptHash(from: policyId)] = Asset(from: asset)
        }
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([ScriptHash: Asset].self)
        
//        if let container = try? decoder.singleValueContainer(),
//           let cborData = try? container.decode(CBOR.self) {
//            // Handle CBOR decoding
//            guard case let .map(cborMap) = cborData else {
//                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected CBOR map")
//            }
//            
//            var decodedData: [ScriptHash: Asset] = [:]
//            for (key, value) in cborMap {
//                guard case let .byteString(policyIdData) = key,
//                      let policyId = try? ScriptHash(payload: policyIdData),
//                      case let .map(assetMap) = value else {
//                    continue
//                }
//                decodedData[policyId] = try Asset(from: assetMap)
//            }
//            self.data = decodedData
//        } else {
//            // Fallback to regular decoding
//            let container = try decoder.singleValueContainer()
//            data = try container.decode([ScriptHash: Asset].self)
//        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
        
//        if encoder is CBOREncoder {
//            var container = encoder.singleValueContainer()
//            var cborMap: CBOR.Map = [:]
//            
//            for (policyId, asset) in data {
//                let assetCbor = try CBOREncoder().encode(asset)
//                cborMap[.byteString(policyId.payload)] = assetCbor.toCBOR
//            }
//            
//            try container.encode(CBOR.map(cborMap))
//        } else {
//            var container = encoder.singleValueContainer()
//            try container.encode(data)
//        }
    }

    public func union(_ other: MultiAsset) -> MultiAsset {
        return self + other
    }

    public static func + (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            newMultiAsset
                .data[key] = (newMultiAsset.data[key] ?? Asset.zero) + value
        }
        return newMultiAsset
    }

    public static func += (lhs: inout MultiAsset, rhs: MultiAsset) {
        lhs = lhs + rhs
    }

    public static func - (lhs: MultiAsset, rhs: MultiAsset) -> MultiAsset {
        var newMultiAsset = lhs
        for (key, value) in rhs.data {
            newMultiAsset
                .data[key] = (newMultiAsset.data[key] ?? Asset.zero) - value
        }
        return newMultiAsset
    }

    public static func == (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        return lhs.data == rhs.data
    }

    public static func <= (lhs: MultiAsset, rhs: MultiAsset) -> Bool {
        for (key, value) in lhs.data {
            if (rhs.data[key]!) < (value ) {
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
