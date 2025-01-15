import Foundation


struct HardForkInitiationAction: Codable {
    public var code: Int { get { return 1 } }
    
    let id: GovActionID?
    let protocolVersion: ProtocolVersion
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        protocolVersion = try container.decode(ProtocolVersion.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(id)
        try container.encode(protocolVersion)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var id: Data
//        var protocolVersion: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            id = list[1] as! Data
//            protocolVersion = list[2] as! Data
//        } else if let tuple = value as? (Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            id = tuple.1 as! Data
//            protocolVersion = tuple.2 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction data: \(value)")
//        }
//        
//        guard code == 1 else {
//            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction type: \(code)")
//        }
//        
//        return HardForkInitiationAction(
//            id: try GovActionID.fromPrimitive(id),
//            protocolVersion: try ProtocolVersion.fromPrimitive(protocolVersion)
//        ) as! T
//    }
}
