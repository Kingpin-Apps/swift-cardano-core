import Foundation
import OrderedCollections

public struct ScriptNofK: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptNofK
    public let required: Int
    public let scripts: [NativeScript]
    
    public init (required: Int, scripts: [NativeScript]) {
        self.required = required
        self.scripts = scripts
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(components) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK type")
        }
        guard components.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK array length")
        }
        guard case let .uint(type) = components[0], type == Self.TYPE.rawValue
        else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK type")
        }
        guard case let .uint(required) = components[1] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK required")
        }
        guard case let .list(scripts) = components[2] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK scripts")
        }
        self.required = Int(required)
        self.scripts = try scripts.map { try NativeScript(from: $0) }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt(Self.TYPE.rawValue)))
        elements.append(.uint(UInt(required)))
        elements.append(.list(try scripts.map { try $0.toPrimitive() }))
        return .list(elements)
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: OrderedDictionary<Primitive, Primitive>) throws -> ScriptNofK {
        guard case let .int(required) = dict[.string("required")] else {
            throw CardanoCoreError.decodingError("Invalid required value")
        }
        
        guard case let .list(scripts) = dict[.string("scripts")] else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        let nativeScripts = try scripts.map {
            guard case let .orderedDict(scriptDict) = $0 else {
                throw CardanoCoreError.decodingError("Invalid NativeScript dictionary")
            }
            return try NativeScript.fromDict(scriptDict)
        }
        
        return ScriptNofK(required: required, scripts: nativeScripts)
    }
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("required")] = .int(required)
        dict[.string("scripts")] = .list(try scripts.map({
            .orderedDict(try $0.toDict() )
        }))
        return dict
    }

}
