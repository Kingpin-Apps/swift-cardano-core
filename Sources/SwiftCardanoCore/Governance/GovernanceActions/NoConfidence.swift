import Foundation


struct NoConfidence: Codable {
    public var code: Int { get { return 3 } }
    
    let id: GovActionID
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 3 else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(id)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var id: [Any]
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            id = list[1] as! [Any]
//        } else if let tuple = value as? (Any, Any) {
//            code = tuple.0 as! Int
//            id = tuple.1 as! [Any]
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid NoConfidence data: \(value)")
//        }
//        
//        guard code == 3 else {
//            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
//        }
//        
//        return NoConfidence(
//            id: try GovActionID.fromPrimitive(id)
//        ) as! T
//    }
}
