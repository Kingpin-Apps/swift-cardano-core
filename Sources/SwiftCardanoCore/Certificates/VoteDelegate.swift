import Foundation
import PotentCBOR

/// Delegate stake to a `DRep`
struct VoteDelegate: Codable {
    public var code: Int { get { return 9 } }
    
    let stakeCredential: StakeCredential
    let drep: DRep
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 9 else {
            throw CardanoCoreError.deserializeError("Invalid VoteDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        drep = try container.decode(DRep.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(drep)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var stakeCredential: Data
//        var drep: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            stakeCredential = list[1] as! Data
//            drep = list[2] as! Data
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            stakeCredential = tuple.1 as! Data
//            drep = tuple.2 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid VoteDelegate data: \(value)")
//        }
//        
//        guard code == 9 else {
//            throw CardanoCoreError.deserializeError("Invalid VoteDelegate type: \(code)")
//        }
//        
//        return VoteDelegate(
//            stakeCredential: try StakeCredential.fromPrimitive(stakeCredential),
//            drep: try DRep.fromPrimitive(drep)
//        ) as! T
//    }
}
