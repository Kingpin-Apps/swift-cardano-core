import Foundation
import OrderedCollections

public struct ScriptNofK: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptNofK
    public let required: Int
    public var scripts: [NativeScript] { scriptList.array }

    /// The scripts, kept so that scripts nested however deep are freed
    /// without recursion.
    var scriptList: NestedList<NativeScript>
    
    public init (required: Int, scripts: [NativeScript]) {
        self.required = required
        self.scriptList = NestedList(scripts)
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
        guard case let .list(scripts) = components[2] else {
            throw CardanoCoreError.deserializeError("Invalid ScriptNofK scripts")
        }
        // script_n_of_k = (3, n : int64, [* native_script])
        self.required = try components[1].integer("ScriptNofK required", as: Int.self)
        self.scriptList = NestedList(try scripts.map { try NativeScript(from: $0) })
    }

    /// The script as a primitive tree; one nested deeper than
    /// ``NativeScript/maxConversionDepth`` as its encoded bytes.
    public func toPrimitive() throws -> Primitive {
        try NativeScript.scriptNofK(self).toPrimitive()
    }

    func primitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt64(Self.TYPE.rawValue)))
        elements.append(.integer(required))
        elements.append(.list(try scripts.map { try $0.primitive() }))
        return .list(elements)
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptNofK {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid ScriptNofK dict format")
        }
        
        guard let requiredPrimitive = dictValue[.string("required")] else {
            throw CardanoCoreError.decodingError("Invalid required value")
        }
        let required = try requiredPrimitive.integer("ScriptNofK required", as: Int.self)
        
        guard let scriptsPrimitive = dictValue[.string("scripts")],
              case let .list(scripts) = scriptsPrimitive else {
            throw CardanoCoreError.decodingError("Invalid ScriptNofK scripts")
        }
        
        let nativeScripts = try scripts.map {
            try NativeScript.fromDict($0)
        }

        return ScriptNofK(required: required, scripts: nativeScripts)
    }
    
    /// The script as JSON.
    ///
    /// - Throws: When it nests deeper than ``NativeScript/maxConversionDepth``.
    public func toDict() throws -> Primitive {
        try NativeScript.scriptNofK(self).toDict()
    }

    func dict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("required")] = .int(Int64(required))
        dict[.string("scripts")] = .list(try scripts.map({ try $0.dict() }))
        return .orderedDict(dict)
    }

}
