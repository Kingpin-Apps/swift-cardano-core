import Foundation
import PotentCBOR

struct StakeRegisterDelegate: ArrayCBORSerializable {
    public var code: Int { get { return 11 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let coin: Coin
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var stakeCredential: Data
        var poolKeyHash: Data
        var coin: Int
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            stakeCredential = list[1] as! Data
            poolKeyHash = list[2] as! Data
            coin = list[3] as! Int
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            stakeCredential = tuple.1 as! Data
            poolKeyHash = tuple.2 as! Data
            coin = tuple.3 as! Int
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate data: \(value)")
        }
        
        guard code == 11 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate type: \(code)")
        }
        
        return StakeRegisterDelegate(
            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
            poolKeyHash: try PoolKeyHash.fromPrimitive(poolKeyHash),
            coin: Coin(coin)
        ) as! T
    }
}

