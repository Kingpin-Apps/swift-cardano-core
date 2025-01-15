import Foundation
import PotentCBOR

struct PoolRetirement: Codable {
    public var code: Int { get { return 4 } }
    
    let poolKeyHash: PoolKeyHash
    let epoch: Int
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 4 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRetirement type: \(code)")
        }
        
        let poolKeyHash = try container.decode(PoolKeyHash.self)
        let epoch = try container.decode(Int.self)
        
        self.poolKeyHash = poolKeyHash
        self.epoch = epoch
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(poolKeyHash)
        try container.encode(epoch)
    }
    
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var poolKeyHash: PoolKeyHash
//        var epoch: Int
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            poolKeyHash = try PoolKeyHash.fromPrimitive(list[1] as! Data)
//            epoch = list[2] as! Int
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            poolKeyHash = try PoolKeyHash.fromPrimitive(tuple.1 as! Data)
//            epoch = tuple.2 as! Int
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid PoolRetirement data: \(value)")
//        }
//        
//        guard code == 4 else {
//            throw CardanoCoreError.deserializeError("Invalid PoolRetirement type: \(code)")
//        }
//        
//        return PoolRetirement(
//            poolKeyHash: poolKeyHash,
//            epoch: epoch
//        ) as! T
//    }
}
