import Foundation
import OrderedCollections

public struct ScriptAny: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptAny
    public var scripts: [NativeScript] { scriptList.array }

    /// The scripts, kept so that scripts nested however deep are freed
    /// without recursion.
    var scriptList: NestedList<NativeScript>

    /// The bytes this script was decoded from, when it was decoded on its
    /// own or as a whole script of a transaction; its encoding and hash are
    /// taken over them, as the ledger takes them, while they are kept.
    public internal(set) var originalCBOR: Data? = nil
    
    public init (scripts: [NativeScript]) {
        self.scriptList = NestedList(scripts)
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let primitiveArray = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAny type")
        }
        
        guard primitiveArray.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAny type")
        }
        
        guard case let .uint(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAny type")
            }
        
        guard let nativeScript = primitiveArray[1].arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAny type")
            }
        self.scriptList = NestedList(try nativeScript.map { try NativeScript(from: $0)})
    }

    /// The script as a primitive tree; one nested deeper than
    /// ``NativeScript/maxConversionDepth`` as its encoded bytes.
    public func toPrimitive() throws -> Primitive {
        try NativeScript.scriptAny(self).toPrimitive()
    }

    func primitive() throws -> Primitive {
        let scriptPrimitives = try scripts.map { try $0.primitive() }
        return .list([.uint(UInt64(Self.TYPE.rawValue)), .list(scriptPrimitives)])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptAny {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid ScriptAny dict format")
        }
        
        guard let scriptsPrimitive = dictValue[.string("scripts")],
              case let .list(scripts) = scriptsPrimitive else {
            throw CardanoCoreError.decodingError("Invalid ScriptAny scripts")
        }
        
        let nativeScripts = try scripts.map {
            try NativeScript.fromDict($0)
        }
        
        return ScriptAny(scripts: nativeScripts)
    }
    
    /// The script as JSON.
    ///
    /// - Throws: When it nests deeper than ``NativeScript/maxConversionDepth``.
    public func toDict() throws -> Primitive {
        try NativeScript.scriptAny(self).toDict()
    }

    func dict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("scripts")] = .list(try scripts.map({ try $0.dict() }))
        return .orderedDict(dict)
    }

}

extension ScriptAny {
    /// Equal when they are the same script, however each was written;
    /// compared without recursing.
    public static func == (lhs: ScriptAny, rhs: ScriptAny) -> Bool {
        NativeScript.scriptAny(lhs) == NativeScript.scriptAny(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        NativeScript.scriptAny(self).hash(into: &hasher)
    }
}
