import Foundation

public struct ScriptPubkey: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptPubkey
    public let keyHash: VerificationKeyHash
    
    public init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case keyHash
    }
    
    public init(from decoder: Swift.Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptPubkey type string")
            }
            
            let payload = try container.decode(String.self, forKey: .keyHash)
            keyHash = VerificationKeyHash(payload: payload.hexStringToData)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptPubkey type string")
            }
            
            keyHash = try container.decode(VerificationKeyHash.self)
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(keyHash.payload.toHex, forKey: .keyHash)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(keyHash)
        }
    }
    
    public static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptPubkey {
        guard let keyHashDict = dict["keyHash"] as? String else {
            throw CardanoCoreError.decodingError("Invalid ScriptPubkey keyHash")
        }
        
        guard let keyHashData = Data(hexString: keyHashDict) else {
            throw CardanoCoreError.decodingError("Invalid hex string for keyHash")
        }
        
        let keyHash = VerificationKeyHash(
            payload: keyHashData
        )
        
        return ScriptPubkey(keyHash: keyHash)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ScriptPubkey type")
        }
        guard case let .uint(type) = primitive[0],
              type == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptPubkey type")
        }
        self.keyHash = try VerificationKeyHash(from: primitive[1])
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.TYPE.rawValue)),
            keyHash.toPrimitive()
        ])
    }

}
