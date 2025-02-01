import Foundation

struct ScriptAny: NativeScript {
    static let type = NativeScriptType.scriptAny
    let scripts: [NativeScripts]
    
    enum CodingKeys: String, CodingKey {
        case type
        case scripts
    }
    
    init (scripts: [NativeScripts]) {
        self.scripts = scripts
    }
    
    init(from decoder: Swift.Decoder) throws {
        if decoder is JSONDecoder {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.type.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptAny type string")
            }
            
            scripts = try container
                .decode([NativeScripts].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == 1 else {
                throw CardanoCoreError.decodingError("Invalid ScriptAny type: \(code)")
            }
            scripts = try container.decode([NativeScripts].self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.type.description(), forKey: .type)
            try container.encode(scripts, forKey: .scripts)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.type.rawValue)
            try container.encode(scripts)
        }
    }
}

