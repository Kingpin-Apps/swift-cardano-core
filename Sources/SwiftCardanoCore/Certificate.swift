import Foundation
import PotentCBOR

typealias UnitInterval = (Int, Int)

enum Credential {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
}

enum Certificate {
    case stakeRegistration(StakeRegistration)
    case stakeDeregistration(StakeDeregistration)
    case stakeDelegation(StakeDelegation)
    case poolRegistration(PoolRegistration)
    case poolRetirement(PoolRetirement)
}

struct StakeCredential: ArrayCBORSerializable {
    public var code: Int {
        get {
            switch credential {
                case .verificationKeyHash(_):
                    return 0
                case .scriptHash(_):
                    return 1
            }
        }
    }
    let credential: Credential
    
    static func fromPrimitive(_ value: Any) throws -> StakeCredential {
        var code: Int
        var payload: Data
        var credential: Credential
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoException.deserializeException("Invalid StakeCredential data: \(value)")
        }
        
        if code == 0 {
            credential = .verificationKeyHash(try VerificationKeyHash(payload: payload))
        } else if code == 1 {
            credential = .scriptHash(try ScriptHash(payload: payload))
        } else {
            throw CardanoException.deserializeException("Invalid StakeCredential type: \(code)")
        }
        
        return StakeCredential(credential: credential)
    }
}

struct StakeRegistration: ArrayCBORSerializable {
    public var code: Int { get { return 0 } }
    let stakeCredential: StakeCredential
    
    static func fromPrimitive(_ value: Any) throws -> StakeRegistration {
        var code: Int
        var payload: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoException.deserializeException("Invalid StakeRegistration data: \(value)")
        }
        
        guard code == 0 else {
            throw CardanoException.deserializeException("Invalid StakeRegistration type: \(code)")
        }
        
        return StakeRegistration(
            stakeCredential: try StakeCredential.fromPrimitive(payload)
        )
    }
}

struct StakeDeregistration: ArrayCBORSerializable {
    public var code: Int { get { return 1 } }
    let stakeCredential: StakeCredential
    
    static func fromPrimitive(_ value: Any) throws -> StakeDeregistration {
        var code: Int
        var payload: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoException.deserializeException("Invalid StakeDeregistration data: \(value)")
        }
        
        guard code == 1 else {
            throw CardanoException.deserializeException("Invalid StakeDeregistration type: \(code)")
        }
        
        return StakeDeregistration(
            stakeCredential: try StakeCredential.fromPrimitive(payload)
        )
    }
}

struct StakeDelegation: ArrayCBORSerializable {
    public var code: Int { get { return 2 } }
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    
    static func fromPrimitive(_ value: Any) throws -> StakeDelegation {
        var code: Int
        var payload: Data
        var poolKeyHash: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
            poolKeyHash = list[2] as! Data
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
            poolKeyHash = tuple.2 as! Data
        } else {
            throw CardanoException.deserializeException("Invalid StakeDelegation data: \(value)")
        }
        
        guard code == 2 else {
            throw CardanoException.deserializeException("Invalid StakeDelegation type: \(code)")
        }
        
        return StakeDelegation(
            stakeCredential: try StakeCredential.fromPrimitive(payload),
            poolKeyHash: try PoolKeyHash(payload: poolKeyHash)
        )
    }
}

struct PoolRegistration: ArrayCBORSerializable {
    public var code: Int { get { return 3 } }
    let poolParams: PoolParams
    
    func toPrimitive() -> Any {
        let result = poolParams.toPrimitive()
        return [code, result]
    }
    
    static func fromPrimitive(_ value: Any) throws -> PoolRegistration {
        var code: Int
        var poolParams: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            poolParams = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            poolParams = tuple.1 as! Data
        } else {
            throw CardanoException.deserializeException("Invalid PoolRegistration data: \(value)")
        }
        
        guard code == 3 else {
            throw CardanoException.deserializeException("Invalid PoolRegistration type: \(code)")
        }
        
        return PoolRegistration(
            poolParams: PoolParams.fromPrimitive(poolParams) as! PoolParams
        )
    }
}


struct PoolRetirement: ArrayCBORSerializable {
    public var code: Int { get { return 4 } }
    
    let poolKeyHash: PoolKeyHash
    let epoch: Int
    
    static func fromPrimitive(_ value: Any) throws -> PoolRetirement {
        var code: Int
        var poolKeyHash: Data
        var epoch: Int
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            poolKeyHash = list[1] as! Data
            epoch = list[2] as! Int
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            poolKeyHash = tuple.1 as! Data
            epoch = tuple.2 as! Int
        } else {
            throw CardanoException.deserializeException("Invalid PoolRetirement data: \(value)")
        }
        
        guard code == 4 else {
            throw CardanoException.deserializeException("Invalid PoolRetirement type: \(code)")
        }
        
        return PoolRetirement(
            poolKeyHash: PoolKeyHash.fromPrimitive(poolKeyHash) as! PoolKeyHash,
            epoch: epoch
        )
    }
}
