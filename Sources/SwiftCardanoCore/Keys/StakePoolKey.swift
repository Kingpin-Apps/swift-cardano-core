import Foundation
import PotentCBOR
import SwiftNcal

public struct StakePoolSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakePoolSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Stake Pool Operator Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

public struct StakePoolVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakePoolVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Stake Pool Operator Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    public func poolKeyHash() throws -> PoolKeyHash {
        return PoolKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: POOL_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
}

public struct StakePoolKeyPair {
    public let signingKey: StakePoolSigningKey
    public let verificationKey: StakePoolVerificationKey
    
    public init(signingKey: StakePoolSigningKey, verificationKey: StakePoolVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakePoolKeyPair
    public static func generate() throws -> StakePoolKeyPair {
        let signingKey = try StakePoolSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakePoolKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: StakePoolSigningKey) throws -> StakePoolKeyPair {
        let verificationKey: StakePoolVerificationKey = try StakePoolVerificationKey.fromSigningKey(signingKey)
        return StakePoolKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakePoolKeyPair
extension StakePoolKeyPair: Equatable {
    public static func == (lhs: StakePoolKeyPair, rhs: StakePoolKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
