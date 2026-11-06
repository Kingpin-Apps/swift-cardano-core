import Foundation

/// A governance credential: a DRep or constitutional committee credential, with
/// CIP-129 and CIP-105 IDs.
public protocol GovernanceCredential: Credential {
    /// The key hash or script hash.
    var credential: CredentialType { get }
    /// The governance role this credential type is for, which sets its Bech32 prefix
    /// and CIP-129 header.
    static var governanceKeyType: GovernanceKeyType { get }
    
    /// Creates a credential from a key hash or script hash.
    /// - Parameter credential: The key hash or script hash.
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
    
    /// Reads a credential from its Bech32 ID, in CIP-129 or CIP-105 form.
    /// - Parameter bech32: The Bech32 ID.
    /// - Throws: When the ID is not valid Bech32 or is for another governance role.
    public init(from bech32: String) throws {
        self = try Self.fromBech32(bech32)
    }
    
    /// Creates a credential from a raw hash.
    /// - Parameters:
    ///   - hex: The 28-byte hash bytes.
    ///   - credentialType: Whether the hash is a key hash or a script hash.
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
    ///   - format: The id format, CIP-129 or CIP-105.
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
    
    /// The ID of this credential as bytes.
    /// - Parameter format: The ID format, CIP-129 by default.
    /// - Returns: For CIP-129, the header byte and the 28-byte hash; for CIP-105, the hash alone.
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
    
    
    /// The Bech32 ID of this credential.
    ///
    /// The human-readable part always comes from ``computeHrp(_:)`` with its
    /// default CIP-129 format, whatever `format` is.
    /// - Parameter format: The ID format of the data part, CIP-129 by default.
    /// - Returns: The Bech32 ID.
    public func toBech32(_ format: IdFormat = .cip129) throws -> String {
        let hrp = self.computeHrp()
        
        let data = try self.toBytes(format)
        
        guard let encoded =  Bech32().encode(hrp: hrp, witprog: data) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(data)")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an Credential object.
    /// - Parameter bech32: Bech32-encoded string.
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
