import Foundation

enum DRepType: Codable, Hashable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case alwaysAbstain
    case alwaysNoConfidence
}

/// Represents a Delegate Representative (DRep) in the Cardano governance system.
///
/// DReps are entities that can represent stake holders in governance decisions.
struct DRep: Codable, Hashable {
    
    var id: String {
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
    
    let credential: DRepType
    
    init(credential: DRepType) {
        self.credential = credential
    }
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
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
    
    var description: String {
        do {
            return try self.toBech32()
        } catch {
            return ""
        }
        
    }
    
    func toBytes() -> Data {
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
    
    func toBech32() throws -> String {
        guard let encoded =  Bech32().encode(hrp: "drep", witprog: self.toBytes()) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(self.toBytes())")
        }
        return encoded
    }
    
}
