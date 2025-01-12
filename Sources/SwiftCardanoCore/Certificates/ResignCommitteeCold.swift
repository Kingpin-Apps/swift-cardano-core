import Foundation
import PotentCBOR

struct ResignCommitteeCold: ArrayCBORSerializable {
    public var code: Int { get { return 15 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let anchor: Anchor?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var committeeColdCredential: Data
        var anchor: Anchor?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            committeeColdCredential = list[1] as! Data
            anchor = try Anchor.fromPrimitive(list[2] as! Data)
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            committeeColdCredential = tuple.1 as! Data
            anchor = try Anchor.fromPrimitive(tuple.2 as! Data)
        } else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold data: \(value)")
        }
        
        guard code == 15 else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type: \(code)")
        }
        
        return ResignCommitteeCold(
            committeeColdCredential: try CommitteeColdCredential.fromPrimitive(committeeColdCredential),
            anchor: anchor
        ) as! T
    }
}

