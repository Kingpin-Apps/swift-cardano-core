import Foundation

//typealias UnitInterval = (Int, Int)
typealias StakeCredential = Credential
typealias DRepCredential = Credential
typealias CommitteeColdCredential = Credential
typealias CommitteeHotCredential = Credential

enum CredentialType: Codable, Hashable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
}

struct Credential: Codable, Hashable {
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
    let credential: CredentialType
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        let credential: CredentialType
        
        if code == 0 {
            let verificationKeyHash = try container.decode(VerificationKeyHash.self)
            credential = .verificationKeyHash(verificationKeyHash)
        } else if code == 1 {
            let scriptHash = try container.decode(ScriptHash.self)
            credential = .scriptHash(scriptHash)
        } else {
            throw CardanoCoreError
                .deserializeError(
                    "Invalid \(type(of: Self.self)) type: \(code)"
                )
        }
        
        self.credential = credential
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(credential)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var payload: Data
//        var credential: CredentialType
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            payload = list[1] as! Data
//        } else if let tuple = value as? (Any, Any) {
//            code = tuple.0 as! Int
//            payload = tuple.1 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid StakeCredential data: \(value)")
//        }
//        
//        if code == 0 {
//            credential = .verificationKeyHash(try VerificationKeyHash(payload: payload))
//        } else if code == 1 {
//            credential = .scriptHash(try ScriptHash(payload: payload))
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid StakeCredential type: \(code)")
//        }
//        
//        return StakeCredential(credential: credential) as! T
//    }
    
    static func == (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.credential == rhs.credential
    }
}
