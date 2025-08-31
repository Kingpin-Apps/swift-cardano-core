import Foundation
import CryptoKit
import PotentCBOR
import PotentCodables

public struct AssetName: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { 32 }
    public static var minSize: Int { 0 }
    
    public init(payload: Data) throws {
        self.payload = payload
    }
    
    public init(from name: String) {
        if !name.hexStringToData.isEmpty {
            self.payload = name.hexStringToData
        } else {
            self.payload = name.data(using: .utf8)!
        }
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
        set { 
            _data = newValue
            _data = normalizeData(_data)
        }
    }
    private var _data: [AssetName: Int] = [:]
    
    public subscript(key: AssetName) -> Int? {
        get { return _data[key] }
        set { 
            if let value = newValue, value != 0 {
                _data[key] = value
            } else {
                _data.removeValue(forKey: key)
            }
        }
    }
    
    public var isEmpty: Bool {
        return data.isEmpty
    }
    
    public var count: Int {
        return data.count
    }
    
    public init(_ data: [AnyHashable: AnyHashable]) {
        self.data = data as! [AssetName: Int]
    }
    
    public init(from primitive: Primitive) throws {
        self.data = [:]
        
        guard case let .dict(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Asset type")
        }
        
        for (key, value) in primitive {
            let assetName: String
            
            switch key {
                case let .string(keyValue):
                    assetName = keyValue
                case let .bytes(dataValue):
                    assetName = dataValue.toHexString()
                default:
                    throw CardanoCoreError.deserializeError("Invalid AssetName type: \(key)")
            }
                    
            guard case let .int(intValue) = value else {
                throw CardanoCoreError.deserializeError("Invalid Asset amount type: \(value)")
            }
            self.data[AssetName(from: assetName)] = intValue
        }
    }
    
    public func toPrimitive() -> Primitive {
        var result = [Primitive: Primitive]()
        for (key, value) in data {
            result[key.toPrimitive()] = .int(value)
        }
        return .dict(result)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([AssetName: Int].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    private func normalizeData(_ data: [AssetName: Int]) -> [AssetName: Int] {
        return data.filter { $0.value != 0 }
    }
    
    public mutating func normalize() -> Asset {
        _data = normalizeData(_data)
        return self
    }
    
    public func remove(_ key: AssetName) -> Asset {
        var result = self
        result.data.removeValue(forKey: key)
        return result
    }

    public func union(_ other: Asset) -> Asset {
        return self + other
    }
    
    public static func + (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) + value
        }
        return result
    }
    
    public static func - (lhs: Asset, rhs: Asset) -> Asset {
        var result = lhs
        for (key, value) in rhs.data {
            result[key] = (result[key] ?? 0) - value
        }
        return result
    }

    public static func < (lhs: Asset, rhs: Asset) -> Bool {
        // lhs < rhs means lhs <= rhs && lhs != rhs
        return lhs <= rhs && lhs != rhs
    }

    public static func <= (lhs: Asset, rhs: Asset) -> Bool {
        // Check if lhs is a subset of rhs with all values <= corresponding rhs values
        for (key, value) in lhs.data {
            guard let rhsValue = rhs.data[key] else {
                // lhs has an asset that rhs doesn't have, so lhs cannot be <= rhs
                return false
            }
            if value > rhsValue {
                // lhs has more of this asset than rhs, so lhs cannot be <= rhs
                return false
            }
        }
        return true
    }

    public static func > (lhs: Asset, rhs: Asset) -> Bool {
        // lhs > rhs means rhs < lhs
        return rhs < lhs
    }

    public static func >= (lhs: Asset, rhs: Asset) -> Bool {
        // lhs >= rhs means rhs <= lhs
        return rhs <= lhs
    }
}
