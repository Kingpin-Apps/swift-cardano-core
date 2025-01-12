import Foundation
import PotentCBOR

struct RegisterDRep: ArrayCBORSerializable {
    public var code: Int { get { return 16 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    let anchor: Anchor? 
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var drepCredential: Data
        var coin: Int
        var anchor: Anchor?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            drepCredential = list[1] as! Data
            coin = list[2] as! Int
            anchor = try Anchor.fromPrimitive(list[3] as! Data)
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            drepCredential = tuple.1 as! Data
            coin = tuple.2 as! Int
            anchor = try Anchor.fromPrimitive(tuple.3 as! Data)
        } else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep data: \(value)")
        }
        
        guard code == 16 else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep type: \(code)")
        }
        
        return RegisterDRep(
            drepCredential: try DRepCredential.fromPrimitive(drepCredential),
            coin: Coin(coin),
            anchor: anchor
        ) as! T
    }
}
