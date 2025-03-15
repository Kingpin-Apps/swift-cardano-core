import Foundation

public struct ScriptNofK: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptNofK
    public let required: Int
    public let scripts: [NativeScript]
    
    enum CodingKeys: String, CodingKey {
        case type
        case required
        case scripts
    }
    
    public init (required: Int, scripts: [NativeScript]) {
        self.required = required
        self.scripts = scripts
    }
    
    public init(from decoder: Swift.Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type string")
            }
            
            required = try container.decode(Int.self, forKey: .required)
            scripts = try container.decode([NativeScript].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptNofK type: \(code)")
            }
            
            required = try container.decode(Int.self)
            scripts = try container.decode([NativeScript].self)
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
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
    
    public static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptNofK {
        guard let required = dict["required"] as? Int else {
            throw CardanoCoreError.decodingError("Invalid required value")
        }
        
        guard let scripts = dict["scripts"] as? [Dictionary<AnyHashable, Any>] else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        let nativeScripts = try scripts.map { try NativeScript.fromDict($0) }
        
        return ScriptNofK(required: required, scripts: nativeScripts)
    }

}
