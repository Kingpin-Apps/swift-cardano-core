import Foundation
import PotentCBOR
import SwiftNcal

public struct StakeSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeSigningKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Stake Signing Key" }
    
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

public struct StakeVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeVerificationKeyShelley_ed25519" }
    public static var DESCRIPTION: String { "Stake Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    public func rewardAccountHash(network: Network) throws -> RewardAccountHash {
        let vKeyHash = VerificationKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: VERIFICATION_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
        let address = try Address(stakingPart: .verificationKeyHash(vKeyHash), network: network)
        return RewardAccountHash(payload: address.toBytes())
    }
}

public struct StakeExtendedSigningKey: ExtendedSigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeExtendedSigningKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Stake Signing Key" }
    
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

public struct StakeExtendedVerificationKey: ExtendedVerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "StakeExtendedVerificationKeyShelley_ed25519_bip32" }
    public static var DESCRIPTION: String { "Stake Verification Key" }
    
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

public struct StakeKeyPair {
    public let signingKey: StakeSigningKey
    public let verificationKey: StakeVerificationKey
    
    public init(signingKey: StakeSigningKey, verificationKey: StakeVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new StakeKeyPair
    public static func generate() throws -> StakeKeyPair {
        let signingKey = try StakeSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a StakeKeyPair from an existing signing key
    public static func fromSigningKey(_ signingKey: StakeSigningKey) throws -> StakeKeyPair {
        let verificationKey: StakeVerificationKey = try StakeVerificationKey.fromSigningKey(signingKey)
        return StakeKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for StakeKeyPair
extension StakeKeyPair: Equatable {
    public static func == (lhs: StakeKeyPair, rhs: StakeKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

