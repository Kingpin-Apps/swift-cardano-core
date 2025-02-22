import Foundation

struct ScriptNofK: NativeScript {
    static let TYPE = NativeScriptType.scriptNofK
    let required: Int
    let scripts: [NativeScripts]
    
    enum CodingKeys: String, CodingKey {
        case type
        case required
        case scripts
    }
    
    init (required: Int, scripts: [NativeScripts]) {
        self.required = required
        self.scripts = scripts
    }
    
    init(from decoder: Swift.Decoder) throws {
        if decoder is JSONDecoder {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type string")
            }
            
            required = try container.decode(Int.self, forKey: .required)
            scripts = try container.decode([NativeScripts].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type: \(code)")
            }
            
            required = try container.decode(Int.self)
            scripts = try container.decode([NativeScripts].self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(required, forKey: .required)
            try container.encode(scripts, forKey: .scripts)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(required)
            try container.encode(scripts)
        }
    }
    
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptNofK {
        guard let required = dict["required"] as? Int else {
            throw CardanoCoreError.decodingError("Invalid required value")
        }
        
        guard let scripts = dict["scripts"] as? [NativeScripts] else {
            throw CardanoCoreError.decodingError("Invalid scripts value")
        }
        
        return ScriptNofK(required: required, scripts: scripts)
    }

}
