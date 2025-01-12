import Foundation
import PotentCBOR


struct StakeVoteDelegate: ArrayCBORSerializable {
    public var code: Int { get { return 10 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let drep: DRep
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var stakeCredential: Data
        var poolKeyHash: Data
        var drep: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            stakeCredential = list[1] as! Data
            poolKeyHash = list[2] as! Data
            drep = list[3] as! Data
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            stakeCredential = tuple.1 as! Data
            poolKeyHash = tuple.2 as! Data
            drep = tuple.3 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteDelegate data: \(value)")
        }
        
        guard code == 10 else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteDelegate type: \(code)")
        }
        
        return StakeVoteDelegate(
            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
            poolKeyHash: try PoolKeyHash.fromPrimitive(poolKeyHash),
            drep: try DRep.fromPrimitive(drep)
        ) as! T
    }
}
