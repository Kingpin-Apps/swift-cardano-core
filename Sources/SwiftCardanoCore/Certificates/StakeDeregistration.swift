import Foundation
import PotentCBOR

struct StakeDeregistration: Codable {
    public var code: Int { get { return 1 } }
    let stakeCredential: StakeCredential
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var payload: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            payload = list[1] as! Data
//        } else if let tuple = value as? (Any, Any) {
//            code = tuple.0 as! Int
//            payload = tuple.1 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration data: \(value)")
//        }
//        
//        guard code == 1 else {
//            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration type: \(code)")
//        }
//        
//        return StakeDeregistration(
//            stakeCredential: try StakeCredential.fromPrimitive(payload)
//        ) as! T
//    }
}
