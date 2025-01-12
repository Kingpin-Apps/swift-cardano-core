import Foundation
import PotentCBOR

struct UpdateDRep: ArrayCBORSerializable {
    public var code: Int { get { return 18 } }
    
    let drepCredential: DRepCredential
    let anchor: Anchor?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var drepCredential: Data
        var anchor: Anchor?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            drepCredential = list[1] as! Data
            anchor = try Anchor.fromPrimitive(list[2] as! Data)
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            drepCredential = tuple.1 as! Data
            anchor = try Anchor.fromPrimitive(tuple.2 as! Data)
        } else {
            throw CardanoCoreError.deserializeError("Invalid UpdateDRep data: \(value)")
        }
        
        guard code == 18 else {
            throw CardanoCoreError.deserializeError("Invalid UpdateDRep type: \(code)")
        }
        
        return UpdateDRep(
            drepCredential: try DRepCredential.fromPrimitive(drepCredential),
            anchor: anchor
        ) as! T
    }
}
