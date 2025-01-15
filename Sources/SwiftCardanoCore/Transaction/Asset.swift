import Foundation
import CryptoKit

class AssetName: ConstrainedBytes {
    static let MAX_SIZE = 32

    override var description: String {
        return "AssetName(\(payload))"
    }
}

struct Asset: Codable, Comparable, Hashable, Equatable, AdditiveArithmetic {

    static var zero: Asset {
        return Asset([:])
    }

    typealias KEY_TYPE = AssetName
    typealias VALUE_TYPE = Int
    
    var data: [KEY_TYPE: VALUE_TYPE] {
        get {
            _data
        }
        set {
            _data = newValue
        }
    }
    private var _data: [KEY_TYPE: VALUE_TYPE] = [:]
    
    subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return _data[key]
        }
        set {
            _data[key] = newValue
        }
    }
    
    init(_ data: [AnyHashable: AnyHashable]) {
        self.data = data as! [KEY_TYPE: VALUE_TYPE]
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        data = try container.decode([KEY_TYPE: VALUE_TYPE].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(data)
    }

    func union(_ other: Asset) -> Asset {
        return self + other
    }
    
    static func + (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) + value
            
            if result[key] == 0 {
                result.data.removeValue(forKey: key)
            }
            
            if result.data.isEmpty {
                return zero
            }
        }
        return result
    }
    
    static func - (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) - value
            
            if result[key] == 0 {
                result.data.removeValue(forKey: key)
            }
            
            if result.data.isEmpty {
                return zero
            }
        }
        return result
    }

    static func < (lhs: Asset, rhs: Asset) -> Bool {
        var result = lhs
        for (key, value) in rhs.data {
            if (rhs.data[key]!) < (value ) {
                return false
            }
        }
        return true
    }
}
