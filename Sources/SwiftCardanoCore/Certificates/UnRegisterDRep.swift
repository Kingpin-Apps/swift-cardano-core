import Foundation
import PotentCBOR


struct UnRegisterDRep: Codable {
    public var code: Int { get { return 17 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 17 else {
            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep type: \(code)")
        }
        
        drepCredential = try container.decode(DRepCredential.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(drepCredential)
        try container.encode(coin)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var drepCredential: Data
//        var coin: Int
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            drepCredential = list[1] as! Data
//            coin = list[2] as! Int
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            drepCredential = tuple.1 as! Data
//            coin = tuple.2 as! Int
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep data: \(value)")
//        }
//        
//        guard code == 17 else {
//            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep type: \(code)")
//        }
//        
//        return UnRegisterDRep(
//            drepCredential: try DRepCredential.fromPrimitive(drepCredential),
//            coin: Coin(coin)
//        ) as! T
//    }
}
