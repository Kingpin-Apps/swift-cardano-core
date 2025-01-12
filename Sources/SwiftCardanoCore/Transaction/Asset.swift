import Foundation
import CryptoKit

class AssetName: ConstrainedBytes {
    static let MAX_SIZE = 32

    override var description: String {
        return "AssetName(\(payload))"
    }
}

class Asset: DictCBORSerializable, Equatable, Comparable {

    typealias KEY_TYPE = AssetName
    typealias VALUE_TYPE = Int
    
    required init(_ data: [AnyHashable: Any]) throws {
        self.data = data as! [KEY_TYPE: VALUE_TYPE]
    }

    func union(_ other: Asset) -> Asset {
        return self + other
    }

    static func + (lhs: Asset, rhs: Asset) -> Asset {
        var newAsset = lhs
        for (key, value) in rhs.data {
            newAsset
                .data[key] = (newAsset.data[key] as! VALUE_TYPE) + (value as! VALUE_TYPE)
        }
        return newAsset
    }

    static func += (lhs: inout Asset, rhs: Asset) {
        lhs = lhs + rhs
    }

    static func - (lhs: Asset, rhs: Asset) -> Asset {
        var newAsset = lhs
        for (key, value) in rhs.data {
            newAsset.data[key] = (newAsset.data[key] as! VALUE_TYPE) - (value as! VALUE_TYPE)
        }
        return newAsset
    }

    static func == (lhs: Asset, rhs: Asset) -> Bool {
        return lhs.data as! [KEY_TYPE: VALUE_TYPE] == rhs.data as! [KEY_TYPE: VALUE_TYPE]
    }
    
    static func < (lhs: Asset, rhs: Asset) -> Bool {
        for (key, value) in lhs.data {
            if (rhs.data[key] as! VALUE_TYPE) < (value as! VALUE_TYPE) {
                return false
            }
        }
        return true
    }

    static func <= (lhs: Asset, rhs: Asset) -> Bool {
        for (key, value) in lhs.data {
            if (rhs.data[key] as! VALUE_TYPE) <= (value as! VALUE_TYPE) {
                return false
            }
        }
        return true
    }
}
