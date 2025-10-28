import Foundation

/// Enum representing the different credential formats.
public enum CredentialFormat {
    case bech32
    case hex
}

/// Enum representing the different ID formats.
public enum IdFormat {
    case cip105
    case cip129
}

/// The credential can be  a verification key hash or a script hash.
public protocol Credential: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    var credential: CredentialType { get }
    
    init(credential: CredentialType)
}

extension Credential {
    
    public var description: String {
        "\(String(describing: Self.self))(\(credential.payload.toHex))"
    }
    
    public var debugDescription: String { self.description }
    
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
        
        self.init(credential: credential)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2,
              case let .uint(code) = primitive[0] else {
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
        
        self.init(credential: credential)
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
            .uint(UInt(code)),
            try self.credential.toPrimitive()
        ])
    }
    
    public static func == (lhs: Self, rhs: any Credential) -> Bool {
        return lhs.credential == rhs.credential
    }
}

public struct StakeCredential: Credential {
    public let credential: CredentialType
    
    public init(credential: CredentialType) {
        self.credential = credential
    }
}

public struct DRepCredential: GovernanceCredential {
    public let credential: CredentialType
    
    static var governanceKeyType: GovernanceKeyType {
        .drep
    }
    
    public init(credential: CredentialType) {
        self.credential = credential
    }
}

public struct CommitteeColdCredential: GovernanceCredential {
    public let credential: CredentialType
    
    static var governanceKeyType: GovernanceKeyType {
        .ccCold
    }
    
    public init(credential: CredentialType) {
        self.credential = credential
    }
}

public struct CommitteeHotCredential: GovernanceCredential {
    public let credential: CredentialType
    
    static var governanceKeyType: GovernanceKeyType {
        .ccHot
    }
    
    public init(credential: CredentialType) {
        self.credential = credential
    }
}
