import Foundation
import PotentCBOR

struct StakeVoteRegisterDelegate: ArrayCBORSerializable {
    public var code: Int { get { return 13 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let drep: DRep
    let coin: Coin
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var stakeCredential: Data
        var poolKeyHash: Data
        var drep: Data
        var coin: Int
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            stakeCredential = list[1] as! Data
            poolKeyHash = list[2] as! Data
            drep = list[3] as! Data
            coin = list[4] as! Int
        } else if let tuple = value as? (Any, Any, Any, Any, Any) {
            code = tuple.0 as! Int
            stakeCredential = tuple.1 as! Data
            poolKeyHash = tuple.2 as! Data
            drep = tuple.3 as! Data
            coin = tuple.4 as! Int
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate data: \(value)")
        }
        
        guard code == 13 else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate type: \(code)")
        }
        
        return StakeVoteRegisterDelegate(
            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
            poolKeyHash: try PoolKeyHash.fromPrimitive(poolKeyHash),
            drep: try DRep.fromPrimitive(drep),
            coin: Coin(coin)
        ) as! T
    }
}
