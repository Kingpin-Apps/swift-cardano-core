import Foundation
import PotentCBOR

struct StakeVoteRegisterDelegate: Codable {
    public var code: Int { get { return 13 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let drep: DRep
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 13 else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        poolKeyHash = try container.decode(PoolKeyHash.self)
        drep = try container.decode(DRep.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(drep)
        try container.encode(coin)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var stakeCredential: Data
//        var poolKeyHash: Data
//        var drep: Data
//        var coin: Int
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            stakeCredential = list[1] as! Data
//            poolKeyHash = list[2] as! Data
//            drep = list[3] as! Data
//            coin = list[4] as! Int
//        } else if let tuple = value as? (Any, Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            stakeCredential = tuple.1 as! Data
//            poolKeyHash = tuple.2 as! Data
//            drep = tuple.3 as! Data
//            coin = tuple.4 as! Int
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate data: \(value)")
//        }
//        
//        guard code == 13 else {
//            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate type: \(code)")
//        }
//        
//        return StakeVoteRegisterDelegate(
//            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
//            poolKeyHash: try PoolKeyHash.fromPrimitive(poolKeyHash),
//            drep: try DRep.fromPrimitive(drep),
//            coin: Coin(coin)
//        ) as! T
//    }
}
