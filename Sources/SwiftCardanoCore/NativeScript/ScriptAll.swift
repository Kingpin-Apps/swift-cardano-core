import Foundation
import OrderedCollections

public struct ScriptAll: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptAll
    public let scripts: [NativeScript]
    
    public init (scripts: [NativeScript]) {
        self.scripts = scripts
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        guard !primitiveArray.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        guard case let .uint(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
            }
        
        guard case let .list(nativeScript) = primitiveArray[1] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
            }
        self.scripts = try nativeScript.map { try NativeScript(from: $0)}
    }

    public func toPrimitive() throws -> Primitive {
        let scriptPrimitives = try scripts.map { try $0.toPrimitive() }
        return .list([.int(Self.TYPE.rawValue), .list(scriptPrimitives)])
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptAll {
        guard case let .orderedDict(dictValue) = dict,
              case let .list(scripts) = dictValue[.string("scripts")] else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        let nativeScripts = try scripts.map {
            try NativeScript.fromDict($0)
        }
        
        return ScriptAll(scripts: nativeScripts)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("scripts")] = .list(try scripts.map({ try $0.toDict() }))
        return .orderedDict(dict)
    }
}
