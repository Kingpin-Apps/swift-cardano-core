import Foundation
import PotentCBOR


struct UnRegisterDRep: ArrayCBORSerializable {
    public var code: Int { get { return 17 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var drepCredential: Data
        var coin: Int
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            drepCredential = list[1] as! Data
            coin = list[2] as! Int
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            drepCredential = tuple.1 as! Data
            coin = tuple.2 as! Int
        } else {
            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep data: \(value)")
        }
        
        guard code == 17 else {
            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep type: \(code)")
        }
        
        return UnRegisterDRep(
            drepCredential: try DRepCredential.fromPrimitive(drepCredential),
            coin: Coin(coin)
        ) as! T
    }
}
