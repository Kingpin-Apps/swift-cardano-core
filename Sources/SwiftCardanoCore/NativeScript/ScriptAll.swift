import Foundation

struct ScriptAll: NativeScript {
    static let type = NativeScriptType.scriptAll
    let scripts: [NativeScripts]
    
    enum CodingKeys: String, CodingKey {
        case type
        case scripts
    }
    
    init (scripts: [NativeScripts]) {
        self.scripts = scripts
    }
    
    init(from decoder: Swift.Decoder) throws {
        if let jsonDecoder = decoder as? JSONDecoder {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.type.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type string")
            }
            
            scripts = try container.decode([NativeScripts].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.type.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type: \(code)")
            }
            scripts = try container.decode([NativeScripts].self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if let jsonEncoder = encoder as? JSONEncoder {
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
