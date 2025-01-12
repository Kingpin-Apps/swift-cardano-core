import Foundation
import PotentCBOR

/// Un-Register a stake credential with an optional refund amount
struct Unregister: ArrayCBORSerializable {
    public var code: Int { get { return 8 } }
    
    let stakeCredential: StakeCredential
    let coin: Coin
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var stakeCredential: Data
        var coin: Int
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            stakeCredential = list[1] as! Data
            coin = list[2] as! Int
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            stakeCredential = tuple.1 as! Data
            coin = tuple.2 as! Int
        } else {
            throw CardanoCoreError.deserializeError("Invalid Unregister data: \(value)")
        }
        
        guard code == 8 else {
            throw CardanoCoreError.deserializeError("Invalid Unregister type: \(code)")
        }
        
        return Unregister(
            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
            coin: Coin(coin)
        ) as! T
    }
}

