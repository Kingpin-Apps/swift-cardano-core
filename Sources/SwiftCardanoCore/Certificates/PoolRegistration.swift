import Foundation
import PotentCBOR

struct PoolRegistration: ArrayCBORSerializable {
    public var code: Int { get { return 3 } }
    let poolParams: PoolParams
    
    func toPrimitive() throws -> Any {
        let result = try poolParams.toPrimitive()
        return [code, result]
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var poolParams: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            poolParams = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            poolParams = tuple.1 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration data: \(value)")
        }
        
        guard code == 3 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type: \(code)")
        }
        
        let params: PoolParams = try PoolParams.fromPrimitive(poolParams)
        return PoolRegistration(poolParams: params) as! T
    }
}
