import Foundation

public typealias StakeCredential = Credential
public typealias DRepCredential = Credential
public typealias CommitteeColdCredential = Credential
public typealias CommitteeHotCredential = Credential

/// Enum representing the different types of credentials.
public enum CredentialType: Codable, Hashable, Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.toPrimitive()
            case .scriptHash(let scriptHash):
                return scriptHash.toPrimitive()
        }
    }
}

/// The credential can be  a verification key hash or a script hash.
public struct Credential: Codable, Hashable, Sendable {
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
    public let credential: CredentialType
    
    public init(credential: CredentialType) {
        self.credential = credential
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 2,
              case let .int(code) = primitive[0] else {
            throw CardanoCoreError.deserializeError("Invalid Credential type")
        }
        
        let credential: CredentialType
        if code == 0 {
            guard case .bytes(_) = primitive[1] else {
                throw CardanoCoreError.deserializeError("Invalid Credential type")
            }
            credential = .verificationKeyHash(try VerificationKeyHash(from: primitive[1]))
        } else if code == 1 {
            guard case .bytes(_) = primitive[1] else {
                throw CardanoCoreError.deserializeError("Invalid Credential type")
            }
            credential = .scriptHash(try ScriptHash(from: primitive[1]))
        } else {
            throw CardanoCoreError.deserializeError("Invalid Credential type")
        }
        
        self.credential = credential
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        
        switch credential {
            case .verificationKeyHash(let verificationKeyHash):
                try container.encode(verificationKeyHash)
            case .scriptHash(let scriptHash):
                try container.encode(scriptHash)
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(code),
            try self.credential.toPrimitive()
        ])
    }
    
    public static func == (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.credential == rhs.credential
    }
}
