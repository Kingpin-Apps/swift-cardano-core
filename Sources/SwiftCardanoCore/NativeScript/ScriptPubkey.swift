import Foundation

struct ScriptPubkey: NativeScript {
    static let type = NativeScriptType.scriptPubkey
    let keyHash: VerificationKeyHash
    
    init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case keyHash
    }
    
    init(from decoder: Swift.Decoder) throws {
        if decoder is JSONDecoder {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.type.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptPubkey type string")
            }
            
            keyHash = try container.decode(VerificationKeyHash.self, forKey: .keyHash)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.type.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptPubkey type string")
            }
            
            keyHash = try container.decode(VerificationKeyHash.self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.type.description(), forKey: .type)
            try container.encode(keyHash, forKey: .keyHash)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.type.rawValue)
            try container.encode(keyHash)
        }
    }
}
