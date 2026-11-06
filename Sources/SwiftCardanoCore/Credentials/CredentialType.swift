import Foundation


/// Enum representing the different types of credentials.
public enum CredentialType: Codable, Hashable, Sendable {
    /// A 28-byte verification key hash.
    case verificationKeyHash(VerificationKeyHash)
    /// A 28-byte script hash.
    case scriptHash(ScriptHash)
    
    /// The raw bytes of the hash.
    public var payload: Data {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                return scriptHash.payload
        }
    }
    
    /// The hash as a CBOR byte string.
    /// - Returns: The primitive form of the hash.
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.toPrimitive()
            case .scriptHash(let scriptHash):
                return scriptHash.toPrimitive()
        }
    }
}
