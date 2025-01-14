import Foundation


struct NoConfidence: ArrayCBORSerializable {
    public var code: Int { get { return 3 } }
    
    let id: GovActionID
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var id: [Any]
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            id = list[1] as! [Any]
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            id = tuple.1 as! [Any]
        } else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence data: \(value)")
        }
        
        guard code == 3 else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
        }
        
        return NoConfidence(
            id: try GovActionID.fromPrimitive(id)
        ) as! T
    }
}
