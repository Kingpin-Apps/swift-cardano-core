import Foundation


/// Enum representing the different types of credentials.
public enum CredentialType: Codable, Hashable, Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    
    public var payload: Data {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                return scriptHash.payload
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.toPrimitive()
            case .scriptHash(let scriptHash):
                return scriptHash.toPrimitive()
        }
    }
}
