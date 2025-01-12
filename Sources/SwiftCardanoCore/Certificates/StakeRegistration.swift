import Foundation
import PotentCBOR


struct StakeRegistration: ArrayCBORSerializable {
    public var code: Int { get { return 0 } }
    let stakeCredential: StakeCredential
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var payload: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration data: \(value)")
        }
        
        guard code == 0 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration type: \(code)")
        }
        
        return StakeRegistration(
            stakeCredential: try StakeCredential.fromPrimitive(payload)
        ) as! T
    }
}
