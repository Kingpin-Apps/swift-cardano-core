import Foundation
import PotentCBOR


struct AuthCommitteeHot: ArrayCBORSerializable {
    public var code: Int { get { return 14 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let committeeHotCredential: CommitteeHotCredential
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var committeeColdCredential: Data
        var committeeHotCredential: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            committeeColdCredential = list[1] as! Data
            committeeHotCredential = list[2] as! Data
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            committeeColdCredential = tuple.1 as! Data
            committeeHotCredential = tuple.2 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot data: \(value)")
        }
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
        }
        
        return AuthCommitteeHot(
            committeeColdCredential: try CommitteeColdCredential.fromPrimitive(committeeColdCredential),
            committeeHotCredential: try CommitteeHotCredential.fromPrimitive(committeeHotCredential)
        ) as! T
    }
}
