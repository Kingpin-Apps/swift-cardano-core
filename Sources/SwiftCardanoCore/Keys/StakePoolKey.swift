import Foundation
import PotentCBOR
import SwiftNcal

struct StakePoolSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakePoolSigningKey_ed25519" }
    static var DESCRIPTION: String { "Stake Pool Operator Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct StakePoolVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "StakePoolVerificationKey_ed25519" }
    static var DESCRIPTION: String { "Stake Pool Operator Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    func poolKeyHash() throws -> PoolKeyHash {
        return PoolKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: POOL_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
}

struct StakePoolKeyPair {
    let signingKey: StakePoolSigningKey
    let verificationKey: StakePoolVerificationKey
    
    init(signingKey: StakePoolSigningKey, verificationKey: StakePoolVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakePoolKeyPair
    static func generate() throws -> StakePoolKeyPair {
        let signingKey = try StakePoolSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakePoolKeyPair from an existing signing key
    static func fromSigningKey(_ signingKey: StakePoolSigningKey) throws -> StakePoolKeyPair {
        let verificationKey: StakePoolVerificationKey = try StakePoolVerificationKey.fromSigningKey(signingKey)
        return StakePoolKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakePoolKeyPair
extension StakePoolKeyPair: Equatable {
    static func == (lhs: StakePoolKeyPair, rhs: StakePoolKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}
