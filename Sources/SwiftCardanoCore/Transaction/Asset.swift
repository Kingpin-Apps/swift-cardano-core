import Foundation
import CryptoKit
import PotentCBOR
import PotentCodables

public struct AssetName: ConstrainedBytes {
    public var payload: Data
    static var maxSize: Int { 32 }
    static var minSize: Int { 0 }
    
    init(payload: Data) throws {
        self.payload = payload
    }
    
    public init(from name: String) {
        self.payload = name.data(using: .utf8)!
    }

    public var description: String {
        return "AssetName(\(String(describing: self.payload.toString)))"
    }
}

public struct Asset: Codable, Comparable, Hashable, Equatable, AdditiveArithmetic {
    public static var zero: Asset {
        return Asset([:])
    }
    
    public var data: [AssetName: Int] {
        get { _data }
        set { _data = newValue }
    }
    private var _data: [AssetName: Int] = [:]
    
    public subscript(key: AssetName) -> Int? {
        get { return _data[key] }
        set { _data[key] = newValue }
    }
    
    public var count: Int {
        return data.count
    }
    
    public init(_ data: [AnyHashable: AnyHashable]) {
        self.data = data as! [AssetName: Int]
    }
    
    public init(from primitive: [String: Int]) {
        self.data = [:]
        for (key, value) in primitive {
            self.data[AssetName(from: key)] = value
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([AssetName: Int].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }

    public func union(_ other: Asset) -> Asset {
        return self + other
    }
    
    public static func + (lhs: Asset, rhs: Asset) -> Asset {
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
    
    public static func - (lhs: Asset, rhs: Asset) -> Asset {
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

    public static func < (lhs: Asset, rhs: Asset) -> Bool {
        for (key, value) in rhs.data {
            if (rhs.data[key]!) < (value ) {
                return false
            }
        }
        return true
    }
}
