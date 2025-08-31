import Foundation

public struct ScriptAll: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptAll
    public let scripts: [NativeScript]
    
    enum CodingKeys: String, CodingKey {
        case type
        case scripts
    }
    
    public init (scripts: [NativeScript]) {
        self.scripts = scripts
    }
    
    public init(from decoder: Swift.Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type string")
            }
            
            scripts = try container.decode([NativeScript].self, forKey: .scripts)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid ScriptAll type: \(code)")
            }
            scripts = try container.decode([NativeScript].self)
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(scripts, forKey: .scripts)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(scripts)
        }
    }
    
    public static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> ScriptAll {
        guard let scripts = dict["scripts"] as? [Dictionary<AnyHashable, Any>] else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        let nativeScripts = try scripts.map { try NativeScript.fromDict($0) }
        
        return ScriptAll(scripts: nativeScripts)
    }

    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        var primitives = Array(primitiveArray)
        
        guard !primitives.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        let first = primitives.removeFirst()
        
        guard case let .int(code) = first,
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
            }
        self.scripts = try primitives.map { try NativeScript(from: $0)}
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Self.TYPE.rawValue))
        elements.append(contentsOf: try scripts.map { try $0.toPrimitive() })
        return .list(elements)
    }

}
