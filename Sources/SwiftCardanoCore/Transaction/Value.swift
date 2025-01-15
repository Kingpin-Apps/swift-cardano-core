import Foundation

struct Value: Codable, Equatable, Hashable {
    
    /// Amount of ADA
    var coin: Int
    
    /// Multi-assets associated with the UTx
    var multiAsset: MultiAsset
    
    init(coin: Int = 0, multiAsset: MultiAsset = MultiAsset([:])) {
        self.coin = coin
        self.multiAsset = multiAsset
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        coin = try container.decode(Int.self)
        multiAsset = try container.decode(MultiAsset.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(coin)
        try container.encode(multiAsset)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 2 else {
//            throw CardanoCoreError
//                .decodingError("Invalid Value data: \(value)")
//        }
//        
//        let coin = list[0] as! Int
//        let multiAsset: MultiAsset = try MultiAsset.fromPrimitive(list[1])
//        
//        return Value(
//            coin: coin,
//            multiAsset: multiAsset
//        ) as! T
//    }

    func union(_ other: Value) -> Value {
        return self + other
    }

    static func + (lhs: Value, rhs: Value) -> Value {
        return Value(
            coin: lhs.coin + rhs.coin,
            multiAsset: lhs.multiAsset + rhs.multiAsset
        )
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(coin)
        hasher.combine(multiAsset)
    }
}
