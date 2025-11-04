import Foundation

public enum DRepType: CBORSerializable, Hashable, Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case alwaysAbstain
    case alwaysNoConfidence
    
    public init(from drepCredential: DRepCredential) throws {
        switch drepCredential.credential {
            case .verificationKeyHash(let verificationKeyHash):
                self = .verificationKeyHash(verificationKeyHash)
            case .scriptHash(let scriptHash):
                self = .scriptHash(scriptHash)
        }
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count >= 1,
              case let .uint(tag) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid DRepType primitive")
        }
        
        switch tag {
            case 0:
                guard elements.count == 2 else {
                    throw CardanoCoreError.deserializeError("Invalid DRepType verificationKeyHash primitive")
                }
                self = .verificationKeyHash(try VerificationKeyHash(from: elements[1]))
            case 1:
                guard elements.count == 2 else {
                    throw CardanoCoreError.deserializeError("Invalid DRepType scriptHash primitive")
                }
                self = .scriptHash(try ScriptHash(from: elements[1]))
            case 2:
                self = .alwaysAbstain
            case 3:
                self = .alwaysNoConfidence
            default:
                throw CardanoCoreError.deserializeError("Invalid DRepType tag: \(tag)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .verificationKeyHash(let hash):
                return .list([.uint(0), hash.toPrimitive()])
            case .scriptHash(let hash):
                return .list([.uint(1), hash.toPrimitive()])
            case .alwaysAbstain:
                return .list([.uint(2)])
            case .alwaysNoConfidence:
                return .list([.uint(3)])
        }
    }
    
    public func toDRepCredential() throws -> DRepCredential {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return DRepCredential(credential: .verificationKeyHash(verificationKeyHash))
            case .scriptHash(let scriptHash):
                return DRepCredential(credential: .scriptHash(scriptHash))
            default:
                throw CardanoCoreError.typeError("Cannot convert DRepType to DRepCredential: \(self)")
        }
    }
    
    public func toGovernanceCredentialType() throws -> GovernanceCredentialType {
        switch self {
            case .verificationKeyHash:
                return .keyHash
            case .scriptHash:
                return .scriptHash
            default:
                throw CardanoCoreError.typeError("Cannot convert DRepType to GovernanceCredentialType")
        }
    }
}

/// Represents a Delegate Representative (DRep) in the Cardano governance system.
///
/// DReps are entities that can represent stake holders in governance decisions.
public struct DRep: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    
    public var code: Int {
        get {
            switch credential {
                case .verificationKeyHash(_):
                    return 0
                case .scriptHash(_):
                    return 1
                case .alwaysAbstain:
                    return 2
                case .alwaysNoConfidence:
                    return 3
            }
        }
    }
    
    public var description: String {
        do {
            return try self.toBech32()
        } catch {
            return "DRep(invalid)"
        }
    }
    
    public var debugDescription: String { self.description }
    
    public let credential: DRepType
    
    public init(credential: DRepType) {
        self.credential = credential
    }
    
    public init(from bech32: String) throws {
        if bech32 == "drep_always_abstain" {
            self.credential = .alwaysAbstain
            return
        } else if bech32 == "drep_always_no_confidence" {
            self.credential = .alwaysNoConfidence
            return
        } else {
            let drepCredential = try DRepCredential(from: bech32)
            self.credential = try DRepType(from: drepCredential)
        }
    }
    
    public init(from hex: Data, as credentialType: GovernanceCredentialType) throws {
        switch credentialType {
            case .keyHash:
                let verificationKeyHash = VerificationKeyHash(payload: hex)
                self.credential = .verificationKeyHash(verificationKeyHash)
            case .scriptHash:
                let scriptHash = ScriptHash(payload: hex)
                self.credential = .scriptHash(scriptHash)
        }
    }
    
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let drepId = try container.decode(String.self)
            
            if Self.isValidBech32(drepId) {
                try self.init(from: drepId)
            } else {
                let parts = drepId.split(separator: "-", maxSplits: 1)
                let credentialType = String(parts[0])
                let credentialHex = String(parts[1])
                
                guard let data = Data(hexString: credentialHex) else {
                    throw CardanoCoreError.decodingError("Invalid hex string for DRepId: \(drepId)")
                }
                
                if credentialType == "keyHash" {
                    try self.init(from: data, as: .keyHash)
                }
                else if credentialType == "scriptHash" {
                    try self.init(from: data, as: .scriptHash)
                } else {
                    throw CardanoCoreError.decodingError("Unexpected credential type in DRepId: \(drepId)")
                }
            }
            
        }
        else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            let credential: DRepType
            
            if code == 0 {
                let verificationKeyHash = try container.decode(VerificationKeyHash.self)
                credential = .verificationKeyHash(verificationKeyHash)
            } else if code == 1 {
                let scriptHash = try container.decode(ScriptHash.self)
                credential = .scriptHash(scriptHash)
            } else if code == 2 {
                credential = .alwaysAbstain
            } else if code == 3 {
                credential = .alwaysNoConfidence
            } else {
                throw CardanoCoreError
                    .deserializeError(
                        "Invalid \(type(of: Self.self)) type: \(code)"
                    )
            }
            self.init(credential: credential)
        }
    }
    
    public init(from primitive: Primitive) throws {
        if case .list(_) = primitive {
            let credential = try DRepType(from: primitive)
            self.init(credential: credential)
        }
        else if case let .string(drepId) = primitive {
            try self.init(from: drepId)
        } else {
            throw CardanoCoreError.decodingError("Invalid DRepId: \(primitive)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            try container.encode(try self.toBech32(.cip129))
        }
        else {
            var container = encoder.unkeyedContainer()
            try container.encode(code)
            
            switch credential {
                case .verificationKeyHash(let verificationKeyHash):
                    try container.encode(verificationKeyHash)
                case .scriptHash(let scriptHash):
                    try container.encode(scriptHash)
                default:
                    break
            }
        }
    }
    
    public func id(_ format: (CredentialFormat, IdFormat) = (.bech32, .cip105)) throws -> String {
        switch format {
            case (.bech32, let idFormat):
                return try self.toBech32(idFormat)
            case (.hex, let idFormat):
                return try self.toBytes(idFormat).toHex
        }
    }
    
    public func idHex(_ format: IdFormat = .cip105) throws -> String {
        return try self.toBytes(format).toHex
    }
    
    public func toBytes(_ format: IdFormat = .cip105) throws -> Data {
        let payload: Data
        switch credential {
            case .verificationKeyHash(_), .scriptHash(_):
                let drepCredential = try credential.toDRepCredential()
                return try drepCredential.toBytes(format)
            case .alwaysAbstain:
                payload = Data([2])
            case .alwaysNoConfidence:
                payload = Data([3])
        }
        
        switch format {
            case .cip105:
                return payload
            case .cip129:
                let headerByte = DRepCredential.computeHeaderByte(
                    keyType: .drep,
                    credentialType: try credential.toGovernanceCredentialType()
                )
                return headerByte + payload
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return try credential.toPrimitive()
    }
    
    /// Encode the DRepId in Bech32 format.
    ///
    /// More info about Bech32 (here)[https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#Bech32].
    
    /// - Returns: Encoded DRepId in Bech32.
    public func toBech32(_ format: IdFormat = .cip105) throws -> String {
        switch credential {
            case .verificationKeyHash(_), .scriptHash(_):
                let drepCredential = try credential.toDRepCredential()
                return try drepCredential.toBech32(format)
            case .alwaysAbstain:
                return "drep_always_abstain"
            case .alwaysNoConfidence:
                return "drep_always_no_confidence"
        }
    }
    
    /// Decode a bech32 string into an DRep object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded DRepId.
    public static func fromBech32(_ drepId: String) throws -> DRep {
        return try DRep(from: .string(drepId))
    }
    
    /// Validate if a given DRepId string is in valid Bech32 format.
    /// - Parameter drepId: The DRepId string to validate.
    /// - Returns: True if valid Bech32 format, false otherwise.
    public static func isValidBech32(_ drepId: String?) -> Bool {
        guard let drepId = drepId, drepId.hasPrefix("drep") else {
            return false
        }
        let decoded = try? Bech32().bech32Decode(drepId)
        return decoded != nil
    }
    
    /// Save the DRep ID to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - format: The credential format (bech32 or hex)
    ///  - overwrite: Whether to overwrite the file if it already exists
    /// - Throws: An error if the file already exists and overwrite is false
    public func save(
        to path: String,
        format: (CredentialFormat, IdFormat) = (.bech32, .cip105),
        overwrite: Bool = false
    ) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        switch format {
            case (.bech32, let idFormat):
                let drepId = try self.toBech32(idFormat)
                try drepId.write(toFile: path, atomically: true, encoding: .utf8)
            case (.hex, let idFormat):
                let drepIdHex = try self.toBytes(idFormat).toHex
                try drepIdHex.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    /// Load file contents from a given path
    /// - Parameter path: The path to the file
    /// - Returns: An instance of the conforming type
    public static func load(from path: String) throws -> Self {
        let id = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .newlines)
        
        if id.hasPrefix("pool") {
            return try self.init(from: id)
        } else {
            return try self.init(from: id.hexStringToData)
        }
    }
}
