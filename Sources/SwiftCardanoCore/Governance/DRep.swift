import Foundation

public enum DRepType: CBORSerializable, Hashable, Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case alwaysAbstain
    case alwaysNoConfidence
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count >= 1,
              case let .int(tag) = elements[0] else {
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
                return .list([.int(0), hash.toPrimitive()])
            case .scriptHash(let hash):
                return .list([.int(1), hash.toPrimitive()])
            case .alwaysAbstain:
                return .list([.int(2)])
            case .alwaysNoConfidence:
                return .list([.int(3)])
        }
    }
}

/// Represents a Delegate Representative (DRep) in the Cardano governance system.
///
/// DReps are entities that can represent stake holders in governance decisions.
public struct DRep: CBORSerializable, Hashable, Sendable {
    
    public var id: String {
        get throws {
            return try self.toBech32()
        }
    }
    
    public var idHex: String {
        get {
            return self.toBytes().toHex
        }
    }
    
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
    
    public let credential: DRepType
    
    public init(credential: DRepType) {
        self.credential = credential
    }
    
    public init(from decoder: Decoder) throws {
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
        
        self.credential = credential
    }
    
    public func encode(to encoder: Encoder) throws {
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
    
    public var description: String {
        do {
            return try self.toBech32()
        } catch {
            return ""
        }
        
    }
    
    public func toBytes() -> Data {
        switch credential {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                return scriptHash.payload
            case .alwaysAbstain:
                return Data([2])
            case .alwaysNoConfidence:
                return Data([3])
                
        }
    }
    
    public init(from primitive: Primitive) throws {
        self.credential = try DRepType(from: primitive)
    }
    
    public func toPrimitive() throws -> Primitive {
        return try credential.toPrimitive()
    }
    
    public func toBech32() throws -> String {
        guard let encoded =  Bech32().encode(hrp: "drep", witprog: self.toBytes()) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(self.toBytes())")
        }
        return encoded
    }
    
}
