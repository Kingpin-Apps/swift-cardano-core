import Foundation
import PotentCBOR

struct VoteRegisterDelegate: Codable {
    public var code: Int { get { return 12 } }
    
    let stakeCredential: StakeCredential
    let drep: DRep
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 12 else {
            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        drep = try container.decode(DRep.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(drep)
        try container.encode(coin)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var stakeCredential: Data
//        var drep: Data
//        var coin: Int
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            stakeCredential = list[1] as! Data
//            drep = list[2] as! Data
//            coin = list[3] as! Int
//        } else if let tuple = value as? (Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            stakeCredential = tuple.1 as! Data
//            drep = tuple.2 as! Data
//            coin = tuple.3 as! Int
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate data: \(value)")
//        }
//        
//        guard code == 12 else {
//            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type: \(code)")
//        }
//        
//        return VoteRegisterDelegate(
//            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
//            drep: try DRep.fromPrimitive(drep),
//            coin: Coin(coin)
//        ) as! T
//    }
}
