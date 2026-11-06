import Foundation
import CBORCodable

/// An Ed25519 constitutional committee cold signing key.
/// Its text-envelope type is `ConstitutionalCommitteeColdSigningKey_ed25519`.
public struct CommitteeColdSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeColdSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Cold Signing Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// An Ed25519 constitutional committee cold verification key.
/// Its text-envelope type is `ConstitutionalCommitteeColdVerificationKey_ed25519`.
public struct CommitteeColdVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeColdVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Cold Verification Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


/// An Ed25519 constitutional committee hot signing key.
/// Its text-envelope type is `ConstitutionalCommitteeHotSigningKey_ed25519`.
public struct CommitteeHotSigningKey: SigningKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeHotSigningKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Hot Signing Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// An Ed25519 constitutional committee hot verification key.
/// Its text-envelope type is `ConstitutionalCommitteeHotVerificationKey_ed25519`.
public struct CommitteeHotVerificationKey: VerificationKeyProtocol {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "ConstitutionalCommitteeHotVerificationKey_ed25519" }
    public static var DESCRIPTION: String { "Constitutional Committee Hot Verification Key" }
    
    /// Creates the key from its bytes.
    /// - Parameters:
    ///   - payload: The key bytes.
    ///   - type: The text-envelope type, or `nil` for ``TYPE``.
    ///   - description: The text-envelope description, or `nil` for ``DESCRIPTION``.
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// A constitutional committee cold signing key together with its verification key.
public struct CommitteeColdKeyPair {
    /// The committee cold signing key.
    public let signingKey: CommitteeColdSigningKey
    /// The committee cold verification key.
    public let verificationKey: CommitteeColdVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: CommitteeColdSigningKey, verificationKey: CommitteeColdVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeColdKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> CommitteeColdKeyPair {
        let signingKey = try CommitteeColdSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a CommitteeColdKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: CommitteeColdSigningKey) throws -> CommitteeColdKeyPair {
        let verificationKey: CommitteeColdVerificationKey = try CommitteeColdVerificationKey.fromSigningKey(signingKey)
        return CommitteeColdKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for PaymentKeyPair
extension CommitteeColdKeyPair: Equatable {
    public static func == (lhs: CommitteeColdKeyPair, rhs: CommitteeColdKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

/// A constitutional committee hot signing key together with its verification key.
public struct CommitteeHotKeyPair {
    /// The committee hot signing key.
    public let signingKey: CommitteeHotSigningKey
    /// The committee hot verification key.
    public let verificationKey: CommitteeHotVerificationKey
    
    /// Creates a key pair from a signing key and its verification key.
    /// - Parameters:
    ///   - signingKey: The signing key.
    ///   - verificationKey: The verification key that belongs to `signingKey`.
    public init(signingKey: CommitteeHotSigningKey, verificationKey: CommitteeHotVerificationKey) {
        self.signingKey = signingKey
        self.verificationKey = verificationKey
    }
    
    // static method to generate a new CommitteeHotKeyPair
    /// A new key pair with a randomly generated signing key.
    public static func generate() throws -> CommitteeHotKeyPair {
        let signingKey = try CommitteeHotSigningKey.generate()
        return try fromSigningKey(signingKey)
    }
    
    // static a PaymentKeyPair from an existing signing key
    /// The key pair of an existing signing key.
    /// - Parameter signingKey: The signing key.
    /// - Returns: The signing key with its verification key.
    public static func fromSigningKey(_ signingKey: CommitteeHotSigningKey) throws -> CommitteeHotKeyPair {
        let verificationKey: CommitteeHotVerificationKey = try CommitteeHotVerificationKey.fromSigningKey(signingKey)
        return CommitteeHotKeyPair(
            signingKey: signingKey,
            verificationKey: verificationKey
        )
    }
}

// Equatable Protocol for CommitteeHotKeyPair
extension CommitteeHotKeyPair: Equatable {
    public static func == (lhs: CommitteeHotKeyPair, rhs: CommitteeHotKeyPair) -> Bool {
        return lhs.signingKey == rhs.signingKey &&
               lhs.verificationKey == rhs.verificationKey
    }
}

