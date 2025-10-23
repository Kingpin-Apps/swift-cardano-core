import Foundation
import PotentCBOR
import PotentCodables
import OrderedCollections


public struct AssetName: ConstrainedBytes, Sendable {
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

    public var debugDescription: String {
        return "AssetName(\(self.payload.toString))"
    }

    public var description: String {
        return "AssetName(\(self.payload.toString))"
    }
}

public struct Asset: CBORSerializable, Comparable, AdditiveArithmetic, Sendable {
    public static var zero: Asset {
        return Asset([:])
    }
    
    public var data: OrderedDictionary<AssetName, Int> {
        get { _data }
        set { 
            _data = newValue
            _data = normalizeData(_data)
        }
    }
    private var _data: OrderedDictionary<AssetName, Int> = [:]
    
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
    
    public init(_ data: OrderedDictionary<AssetName, Int>) {
        self.data = data
    }
    
    public init(from primitive: Primitive) throws {
        self.data = [:]
        
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid Asset type")
        }
        
        for (key, value) in primitiveDict {
            let assetName: String
            
            switch key {
                case let .string(keyValue):
                    assetName = keyValue
                case let .bytes(dataValue):
                    assetName = dataValue.toHexString()
                default:
                    throw CardanoCoreError.deserializeError("Invalid AssetName type: \(key)")
            }
            
            // Extract coin from first element which can be .int or .uint\
            let coinValue: Int
            switch value {
                case .int(let v):
                    coinValue = v
                case .uint(let v):
                    coinValue = Int(v)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Asset amount type: \(value)")
            }
            
            self.data[AssetName(from: assetName)] = Int(coinValue)
        }
    }
    
    public func toPrimitive() -> Primitive {
        var result: OrderedDictionary<Primitive, Primitive> = [:]
        for (key, value) in data {
            result[key.toPrimitive()] = .int(value)
        }
        return .orderedDict(result)
    }
    
    private func normalizeData(_ data: OrderedDictionary<AssetName, Int>) -> OrderedDictionary<AssetName, Int> {
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
