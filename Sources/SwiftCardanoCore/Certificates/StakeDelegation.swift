import Foundation
import PotentCBOR

struct StakeDelegation: ArrayCBORSerializable {
    public var code: Int { get { return 2 } }
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var payload: Data
        var poolKeyHash: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
            poolKeyHash = list[2] as! Data
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
            poolKeyHash = tuple.2 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeDelegation data: \(value)")
        }
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid StakeDelegation type: \(code)")
        }
        
        return StakeDelegation(
            stakeCredential: try StakeCredential.fromPrimitive(payload),
            poolKeyHash: try PoolKeyHash(payload: poolKeyHash)
        ) as! T
    }
}
