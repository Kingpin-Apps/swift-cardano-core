import Foundation

struct BeforeScript: NativeScript {
    static let TYPE = NativeScriptType.invalidBefore
    let slot: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case slot
    }
    
    init (slot: Int) {
        self.slot = slot
    }

    
    init(from decoder: Swift.Decoder) throws {
        if decoder is JSONDecoder {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid BeforeScript type string")
            }
            
            slot = try container.decode(Int.self, forKey: .slot)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid BeforeScript type: \(code)")
            }
            
            slot = try container.decode(Int.self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(slot, forKey: .slot)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(slot)
        }
    }
    
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> BeforeScript {
        guard let slot = dict["slot"] as? Int else {
            throw CardanoCoreError.decodingError("Invalid BeforeScript slot")
            
        }
        
        return BeforeScript(slot: slot)
    }

}
