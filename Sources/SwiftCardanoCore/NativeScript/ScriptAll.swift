import Foundation

struct ScriptAll: NativeScript {
    static let TYPE = NativeScriptType.scriptAll
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
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type string")
            }
            
            scripts = try container.decode([NativeScripts].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type: \(code)")
            }
            scripts = try container.decode([NativeScripts].self)
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        if encoder is JSONEncoder {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(scripts, forKey: .scripts)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(scripts)
        }
    }
    
    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptAll {
        guard let scripts = dict["scripts"] as? [Dictionary<AnyHashable, Any>] else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        var nativeScripts = [NativeScripts]()
        for script in scripts {
            nativeScripts.append(try NativeScripts.fromDict(script))
        }
        
        return ScriptAll(scripts: nativeScripts)
    }

}
