import Foundation

struct ScriptPubkey: NativeScript {
    static let TYPE = NativeScriptType.scriptPubkey
    let keyHash: VerificationKeyHash
    
    init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case keyHash
    }
    
    init(from decoder: Swift.Decoder) throws {
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

    func encode(to encoder: Swift.Encoder) throws {
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
    
    static func fromJSON(_ json: String) throws -> Self {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptPubkey {
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
}
