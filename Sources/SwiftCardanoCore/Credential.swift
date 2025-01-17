import Foundation

typealias StakeCredential = Credential
typealias DRepCredential = Credential
typealias CommitteeColdCredential = Credential
typealias CommitteeHotCredential = Credential

/// Enum representing the different types of credentials.
enum CredentialType: Codable, Hashable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
}

/// The credential can be  a verification key hash or a script hash.
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
    
    init(credential: CredentialType) {
        self.credential = credential
    }
    
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
        
        switch credential {
            case .verificationKeyHash(let verificationKeyHash):
                try container.encode(verificationKeyHash)
            case .scriptHash(let scriptHash):
                try container.encode(scriptHash)
        }
    }
    
    static func == (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.credential == rhs.credential
    }
}
