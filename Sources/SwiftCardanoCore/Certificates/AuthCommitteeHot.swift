import Foundation
import PotentCBOR


struct AuthCommitteeHot: Codable {
    public var code: Int { get { return 14 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let committeeHotCredential: CommitteeHotCredential
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
        }
        
        committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        committeeHotCredential = try container.decode(CommitteeHotCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(committeeColdCredential)
        try container.encode(committeeHotCredential)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var committeeColdCredential: Data
//        var committeeHotCredential: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            committeeColdCredential = list[1] as! Data
//            committeeHotCredential = list[2] as! Data
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            committeeColdCredential = tuple.1 as! Data
//            committeeHotCredential = tuple.2 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot data: \(value)")
//        }
//        
//        guard code == 14 else {
//            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
//        }
//        
//        return AuthCommitteeHot(
//            committeeColdCredential: try CommitteeColdCredential.fromPrimitive(committeeColdCredential),
//            committeeHotCredential: try CommitteeHotCredential.fromPrimitive(committeeHotCredential)
//        ) as! T
//    }
}
