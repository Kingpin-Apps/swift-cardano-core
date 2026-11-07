import Foundation
import OrderedCollections

/// A native script that requires all of its scripts: `[1, [scripts]]`. cardano-cli JSON type `"all"`.
public struct ScriptAll: NativeScriptable {
    public static let TYPE = NativeScriptType.scriptAll
    /// The scripts that must all be satisfied.
    public var scripts: [NativeScript] { scriptList.array }

    /// The scripts, kept so that scripts nested however deep are freed
    /// without recursion.
    var scriptList: NestedList<NativeScript>

    /// The bytes this script was decoded from, when it was decoded on its
    /// own or as a whole script of a transaction; its encoding and hash are
    /// taken over them, as the ledger takes them, while they are kept.
    public internal(set) var originalCBOR: Data? = nil
    
    /// Creates a script that requires all of `scripts`.
    ///
    /// - Parameter scripts: The scripts that must all be satisfied.
    public init (scripts: [NativeScript]) {
        self.scriptList = NestedList(scripts)
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let primitiveArray = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        guard primitiveArray.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
        }
        
        guard case let .uint(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
            }
        
        guard let nativeScript = primitiveArray[1].arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid ScriptAll type")
            }
        self.scriptList = NestedList(try nativeScript.map { try NativeScript(from: $0)})
    }

    /// The script as a primitive tree; one nested deeper than
    /// ``NativeScript/maxConversionDepth`` as its encoded bytes.
    public func toPrimitive() throws -> Primitive {
        try NativeScript.scriptAll(self).toPrimitive()
    }

    func primitive() throws -> Primitive {
        let scriptPrimitives = try scripts.map { try $0.primitive() }
        return .list([.int(Int64(Self.TYPE.rawValue)), .list(scriptPrimitives)])
    }

    // MARK: - JSONSerializable
    
    /// Reads the script from its JSON form.
    ///
    /// - Throws: When the JSON is not this script, or nests deeper than
    ///   ``NativeScript/maxConversionDepth``.
    public static func fromDict(_ dict: Primitive) throws -> ScriptAll {
        try fromDict(dict, level: 1)
    }

    /// Reads the script at depth `level` of the JSON, the outermost at 1.
    static func fromDict(_ dict: Primitive, level: Int) throws -> ScriptAll {
        try checkJSONDepth(level, limit: NativeScript.maxConversionDepth, "Native script JSON")
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll dict format")
        }
        
        guard let scriptsPrimitive = dictValue[.string("scripts")],
              case let .list(scripts) = scriptsPrimitive else {
            throw CardanoCoreError.decodingError("Invalid ScriptAll scripts")
        }
        
        let nativeScripts = try scripts.map {
            try NativeScript.fromDict($0, level: level + 1)
        }
        
        return ScriptAll(scripts: nativeScripts)
    }
    
    /// The script as JSON.
    ///
    /// - Throws: When it nests deeper than ``NativeScript/maxConversionDepth``.
    public func toDict() throws -> Primitive {
        try NativeScript.scriptAll(self).toDict()
    }

    func dict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("scripts")] = .list(try scripts.map({ try $0.dict() }))
        return .orderedDict(dict)
    }
}

extension ScriptAll {
    /// Equal when they are the same script, however each was written;
    /// compared without recursing.
    public static func == (lhs: ScriptAll, rhs: ScriptAll) -> Bool {
        NativeScript.scriptAll(lhs) == NativeScript.scriptAll(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        NativeScript.scriptAll(self).hash(into: &hasher)
    }
}
