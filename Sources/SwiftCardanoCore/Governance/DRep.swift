import Foundation

enum DRepType {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case other(Data)
}

struct DRep: ArrayCBORSerializable {
    public var code: Int {
        get {
            switch credential {
                case .verificationKeyHash(_):
                    return 0
                case .scriptHash(_):
                    return 1
                case .other(_):
                    return 2
            }
        }
    }
    let credential: DRepType
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var payload: Data
        var credential: CredentialType
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeCredential data: \(value)")
        }
        
        if code == 0 {
            credential = .verificationKeyHash(try VerificationKeyHash(payload: payload))
        } else if code == 1 {
            credential = .scriptHash(try ScriptHash(payload: payload))
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeCredential type: \(code)")
        }
        
        return StakeCredential(credential: credential) as! T
    }
}
