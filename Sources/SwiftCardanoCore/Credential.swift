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

protocol GovernanceCredential: Credential {
    var credential: CredentialType { get }
    static var governanceKeyType: GovernanceKeyType { get }
    
    init(credential: CredentialType)
}

extension GovernanceCredential {
    
    public var description: String {
        do {
            return try self.toBech32()
        } catch {
            return "\(String(describing: Self.self))(invalid_bech32_id)"
        }
    }
    
    public init(from bech32: String) throws {
        self = try Self.fromBech32(bech32)
    }
    
    public init(from hex: Data, as credentialType: GovernanceCredentialType) throws {
        switch credentialType {
            case .keyHash:
                let verificationKeyHash = VerificationKeyHash(payload: hex)
                self.init(credential: .verificationKeyHash(verificationKeyHash))
            case .scriptHash:
                let scriptHash = ScriptHash(payload: hex)
                self.init(credential: .scriptHash(scriptHash))
        }
    }
    
    /// Get the ID in bech32 or hex format
    public func id(_ format: (CredentialFormat, IdFormat) = (.bech32, .cip129)) throws -> String {
        switch format {
            case (.bech32, let idFormat):
                return try self.toBech32(idFormat)
            case (.hex, let idFormat):
                return try self.toBytes(idFormat).toHex
        }
    }
    
    /// Compute the header byte.
    /// - Parameters:
    ///   - keyType: Type of key.
    ///   - credentialType: Type of credential.
    /// - Returns: Data containing the header byte.
    public static func computeHeaderByte(keyType: GovernanceKeyType, credentialType: GovernanceCredentialType) -> Data {
        let header = (keyType.rawValue << 4 | credentialType.rawValue)
        return Data([UInt8(header)])
    }
    
    /// Compute human-readable prefix for bech32 encoder.
    ///
    /// Based on [miscellaneous section](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0005#miscellaneous) in CIP-5.
    /// - Parameters:
    ///   - credentialType: Type of credential.
    /// - Returns: The human-readable prefix.
    public func computeHrp(_ format: IdFormat = .cip129) -> String {
        let prefix: String
        switch Self.governanceKeyType {
            case .ccHot:
                prefix = "cc_hot"
            case .ccCold:
                prefix = "cc_cold"
            case .drep:
                prefix = "drep"
        }
        
        let suffix: String
        switch self.credential {
            case .verificationKeyHash(_):
                suffix = ""
            case .scriptHash(_):
                suffix = "_script"
        }
        
        switch format {
            case .cip105:
                return prefix + suffix
            case .cip129:
                return prefix
        }
    }
    
    public func toBytes(_ format: IdFormat = .cip129) throws -> Data {
        let payload: Data
        let credentialType: GovernanceCredentialType
        switch credential {
            case .verificationKeyHash(let verificationKeyHash):
                payload = verificationKeyHash.payload
                credentialType = .keyHash
            case .scriptHash(let scriptHash):
                payload = scriptHash.payload
                credentialType = .scriptHash
        }
        
        switch format {
            case .cip105:
                return payload
            case .cip129:
                let headerByte = Self.computeHeaderByte(
                    keyType: Self.governanceKeyType,
                    credentialType: credentialType
                )
                return headerByte + payload
        }
    }
    
    /// Encode the in Bech32 format.
    ///
    /// More info about Bech32 (here)[https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#Bech32].
    
    /// - Returns: Encoded in Bech32.
    public func toBech32(_ format: IdFormat = .cip129) throws -> String {
        let hrp = self.computeHrp()
        
        let data = try self.toBytes(format)
        
        guard let encoded =  Bech32().encode(hrp: hrp, witprog: data) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(data)")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an Credential object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded Credential.
    public static func fromBech32(_ bech32: String) throws -> Self {
        let _bech32 = Bech32()
        let (hrp, checksum, _) = try _bech32.bech32Decode(bech32)
        let data = _bech32.convertBits(data: checksum, fromBits: 5, toBits: 8, pad: false)
        
        guard let data else {
            throw CardanoCoreError.decodingError("Invalid bech32 string")
        }
        
        if data.count == VERIFICATION_KEY_HASH_SIZE {
            // CIP-0105
            if hrp.contains("script") {
                return try Self.init(from: data, as: .scriptHash)
            } else {
                return try Self.init(from: data, as: .keyHash)
            }
        }
        else if data.count == CIP129_PAYLOAD_SIZE {
            // CIP-0129
            let header = data[0]
            let payload = data.dropFirst()
            
            let keyTypeBits = (UInt8(header) & 0xF0) >> 4
            let credentialTypeBits = UInt8(header & 0x0F)
            
            guard let keyType = GovernanceKeyType(rawValue: Int(keyTypeBits)) else {
                throw CardanoCoreError.decodingError("Invalid key type type in header: \(header)")
            }
            
            guard keyType == Self.governanceKeyType else {
                throw CardanoCoreError.decodingError("Invalid credential type for \(String(describing: Self.self)): \(keyType)")
            }
            
            guard let governanceCredentialType = GovernanceCredentialType(rawValue: Int(credentialTypeBits)) else {
                throw CardanoCoreError.decodingError("Invalid credential type in header: \(header)")
            }
            
            switch governanceCredentialType {
                case .keyHash:
                    return try self.init(from: payload, as: .keyHash)
                case .scriptHash:
                    return try self.init(from: payload, as: .scriptHash)
            }
        } else {
            throw CardanoCoreError.valueError("Invalid Governance Key format. Should be a valid bech32 format.")
        }
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
