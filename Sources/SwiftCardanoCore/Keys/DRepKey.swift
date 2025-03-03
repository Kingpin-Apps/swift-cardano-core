import Foundation
import PotentCBOR

public struct DRepSigningKey: SigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "DRepSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Delegated Representative Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct DRepVerificationKey: VerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "DRepVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Delegated Representative Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct DRepKeyPair {
    public let signingKey: DRepSigningKey
    public let verificationKey: DRepVerificationKey
    
    public init(signingKey: DRepSigningKey, verificationKey: DRepVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new DRepKeyPair
    public static func generate() throws -> DRepKeyPair {
        let signingKey = try DRepSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a DRepKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: DRepSigningKey) throws -> DRepKeyPair {
        let verificationKey: DRepVerificationKey = try DRepVerificationKey.fromSigningKey(signingKey)
        return DRepKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension DRepKeyPair: Equatable {
    public static func == (lhs: DRepKeyPair, rhs: DRepKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
