import Foundation
import PotentCBOR

/// Register a stake credential with an optional deposit amount.
struct Register: Codable {
    public var code: Int { get { return 7 } }
    
    let stakeCredential: StakeCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 7 else {
            throw CardanoCoreError.deserializeError("Invalid Register type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(coin)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var stakeCredential: Data
//        var coin: Int
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            stakeCredential = list[1] as! Data
//            coin = list[2] as! Int
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            stakeCredential = tuple.1 as! Data
//            coin = tuple.2 as! Int
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid Register data: \(value)")
//        }
//        
//        guard code == 7 else {
//            throw CardanoCoreError.deserializeError("Invalid Register type: \(code)")
//        }
//        
//        return Register(
//            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
//            coin: Coin(coin)
//        ) as! T
//    }
}
