import Foundation
import CryptoKit

class AssetName: ConstrainedBytes {
    static let MAX_SIZE = 32

    override var description: String {
        return "AssetName(\(payload))"
    }
}

class Asset: DictCBORSerializable {

    typealias KEY_TYPE = AssetName
    typealias VALUE_TYPE = Int
    
    required init(_ data: [AnyHashable: AnyHashable]) throws {
        try super.init(data as! [KEY_TYPE: VALUE_TYPE])
    }

    func union(_ other: Asset) -> Asset {
        return self + other as! Asset
    }
}
