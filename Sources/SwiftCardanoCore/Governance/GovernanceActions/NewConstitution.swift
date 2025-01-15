import Foundation


struct NewConstitution: Codable {
    public var code: Int { get { return 5 } }
    
    let id: GovActionID
    let constitution: Constitution
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 5 else {
            throw CardanoCoreError.deserializeError("Invalid NewConstitution type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        constitution = try container.decode(Constitution.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(id)
        try container.encode(constitution)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var id: Data
//        var constitution: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            id = list[1] as! Data
//            constitution = list[2] as! Data
//        } else if let tuple = value as? (Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            id = tuple.1 as! Data
//            constitution = tuple.2 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid NewConstitution data: \(value)")
//        }
//        
//        guard code == 5 else {
//            throw CardanoCoreError.deserializeError("Invalid NewConstitution type: \(code)")
//        }
//        
//        return NewConstitution(
//            id: try GovActionID.fromPrimitive(id),
//            constitution: try Constitution.fromPrimitive(constitution)
//        ) as! T
//    }
}
