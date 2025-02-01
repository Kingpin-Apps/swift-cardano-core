import Foundation

struct ScriptNofK: NativeScript {
    static let type = NativeScriptType.scriptNofK
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
            
            guard typeString == Self.type.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type string")
            }
            
            required = try container.decode(Int.self, forKey: .required)
            scripts = try container.decode([NativeScripts].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.type.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type: \(code)")
            }
            
            required = try container.decode(Int.self)
            scripts = try container.decode([NativeScripts].self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.type.description(), forKey: .type)
            try container.encode(required, forKey: .required)
            try container.encode(scripts, forKey: .scripts)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.type.rawValue)
            try container.encode(required)
            try container.encode(scripts)
        }
    }
}
