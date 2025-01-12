import Foundation

struct Value: ArrayCBORSerializable, Equatable {
    
    /// Amount of ADA
    var coin: Int = 0
    
    /// Multi-assets associated with the UTx
    var multiAsset: MultiAsset = try! MultiAsset([:])
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }

    func union(_ other: Value) -> Value {
        return self + other
    }

    static func + (lhs: Value, rhs: Value) -> Value {
        return Value(coin: lhs.coin + rhs.coin, multiAsset: lhs.multiAsset + rhs.multiAsset)
    }

    static func += (lhs: inout Value, rhs: Value) {
        lhs = lhs + rhs
    }

    static func - (lhs: Value, rhs: Value) -> Value {
        return Value(coin: lhs.coin - rhs.coin, multiAsset: lhs.multiAsset - rhs.multiAsset)
    }

    static func == (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin == rhs.coin && lhs.multiAsset == rhs.multiAsset
    }

    static func <= (lhs: Value, rhs: Value) -> Bool {
        return lhs.coin <= rhs.coin && lhs.multiAsset <= rhs.multiAsset
    }

    static func < (lhs: Value, rhs: Value) -> Bool {
        return lhs <= rhs && lhs != rhs
    }
}
