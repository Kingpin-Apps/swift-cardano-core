import Foundation


struct HardForkInitiationAction: ArrayCBORSerializable {
    public var code: Int { get { return 1 } }
    
    let id: GovActionID?
    let protocolVersion: ProtocolVersion
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var id: Data
        var protocolVersion: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            id = list[1] as! Data
            protocolVersion = list[2] as! Data
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            id = tuple.1 as! Data
            protocolVersion = tuple.2 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction data: \(value)")
        }
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction type: \(code)")
        }
        
        return HardForkInitiationAction(
            id: try GovActionID.fromPrimitive(id),
            protocolVersion: try ProtocolVersion.fromPrimitive(protocolVersion)
        ) as! T
    }
}
