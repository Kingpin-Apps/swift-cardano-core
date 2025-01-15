import Foundation
import PotentCBOR

struct ResignCommitteeCold: Codable {
    public var code: Int { get { return 15 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 15 else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type: \(code)")
        }
        
        committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        anchor = try container.decodeIfPresent(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(committeeColdCredential)
        try container.encode(anchor)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var committeeColdCredential: Data
//        var anchor: Anchor?
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            committeeColdCredential = list[1] as! Data
//            anchor = try Anchor.fromPrimitive(list[2] as! Data)
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            committeeColdCredential = tuple.1 as! Data
//            anchor = try Anchor.fromPrimitive(tuple.2 as! Data)
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold data: \(value)")
//        }
//        
//        guard code == 15 else {
//            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type: \(code)")
//        }
//        
//        return ResignCommitteeCold(
//            committeeColdCredential: try CommitteeColdCredential.fromPrimitive(committeeColdCredential),
//            anchor: anchor
//        ) as! T
//    }
}

