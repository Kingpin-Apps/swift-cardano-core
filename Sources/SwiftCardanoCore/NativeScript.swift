import Foundation
import CryptoKit


// MARK: - MetadataType
enum NativeScriptType: Int {
    case scriptPubkey = 0
    case scriptAll = 1
    case scriptAny = 2
    case scriptNofK = 3
    case invalidBefore = 4
    case invalidHereAfter = 5
    
    public static func fromName(_ name: String) -> NativeScriptType? {
        switch name.lowercased() {
            case "sig": return .scriptPubkey
            case "all": return .scriptAll
            case "any": return .scriptAny
            case "atLeast": return .scriptNofK
            case "after": return .invalidBefore
            case "before": return .invalidHereAfter
            default: return nil
        }
    }
}

/// The metadata for a native script.
class NativeScript: ArrayCBORSerializable, Equatable {
    class var type: Int { return 0 }
    class var jsonTag: String { return "" }
    class var jsonField: String { return "" }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let value = value as? [Any] else {
            throw CardanoCoreError.decodingError("Invalid NativeScript data: \(value)")
        }
        
        let scriptType = value[0] as! Int
        switch scriptType {
            case ScriptPubkey.type:
                let pubkey: ScriptPubkey = try ScriptPubkey.fromPrimitive(value.dropFirst())
                return pubkey as! T
            case ScriptAll.type:
                let all: ScriptAll = try ScriptAll.fromPrimitive(value.dropFirst())
                return all as! T
            case ScriptAny.type:
                let any: ScriptAny = try ScriptAny.fromPrimitive(value.dropFirst())
                return any as! T
            case ScriptNofK.type:
                let nofK: ScriptNofK = try ScriptNofK.fromPrimitive(value.dropFirst())
                return nofK as! T
            case InvalidBefore.type:
                let invalidBefore: InvalidBefore = try InvalidBefore.fromPrimitive(value.dropFirst())
                return invalidBefore as! T
            case InvalidHereAfter.type:
                let invalidHereAfter: InvalidHereAfter = try InvalidHereAfter.fromPrimitive(value.dropFirst())
                return invalidHereAfter as! T
            default:
                throw CardanoCoreError.decodingError("Unknown script type indicator: \(scriptType)")
        }
    }

    func hash() throws -> ScriptHash {
        let cborBytes = try! JSONSerialization.data(withJSONObject: self.toCBOR(), options: [])
        return try ScriptHash(payload: Data(SHA256.hash(data: cborBytes)))
    }
    
    static func == (lhs: NativeScript, rhs: NativeScript) -> Bool {
        switch (lhs, rhs) {
            case let (lhs as ScriptPubkey, rhs as ScriptPubkey):
                return lhs.keyHash == rhs.keyHash
            case let (lhs as ScriptAll, rhs as ScriptAll):
                return lhs.nativeScripts == rhs.nativeScripts
            case let (lhs as ScriptAny, rhs as ScriptAny):
                return lhs.nativeScripts == rhs.nativeScripts
            case let (lhs as ScriptNofK, rhs as ScriptNofK):
                return lhs.nativeScripts == rhs.nativeScripts
            case let (lhs as InvalidBefore, rhs as InvalidBefore):
                return lhs.before == rhs.before
            case let (lhs as InvalidHereAfter, rhs as InvalidHereAfter):
                return lhs.after == rhs.after
            default:
                return false
        }
    }
    
    /// Parse a standard native script dictionary (potentially parsed from a JSON file).
    /// - Parameter scriptJson: The script dictionary.
    /// - Returns: The native script object.
    class func fromDict<T: NativeScript>(_ scriptJson: [String: Any]) throws -> T {
        let scriptPrimitive = try _scriptJsonToPrimitive(scriptJson)
        return try fromPrimitive(scriptPrimitive)
    }
    
    /// Serialize a standard JSON native script into a primitive array
    /// - Parameter scriptJson: The script dictionary.
    /// - Returns: The primitive array.
    private class func _scriptJsonToPrimitive(_ scriptJson: [String: Any]) throws -> [Any] {
        guard let scriptType = scriptJson["type"] as? String,
              let scriptTypeInt = NativeScriptType.fromName(scriptType) else {
            throw CardanoCoreError.decodingError("Invalid script type: \(scriptJson)")
        }
        
        var nativeScript: [Any] = [scriptTypeInt]
        
        for (key, value) in scriptJson {
            if key == "type" {
                continue
            } else if key == "scripts", let scriptList = value as? [[String: Any]] {
                nativeScript.append(try _scriptJsonsToPrimitive(scriptList))
            } else {
                nativeScript.append(value)
            }
        }
        return nativeScript
    }
    
    // Convert list of JSON dictionaries to primitive arrays
    private class func _scriptJsonsToPrimitive(_ scriptJsons: [[String: Any]]) throws -> [[Any]] {
        return try scriptJsons.map { try _scriptJsonToPrimitive($0) }
    }
    
    // Convert NativeScript object to JSON dictionary
    func toDict() -> [String: Any] {
        var script: [String: Any] = [:]
        script["type"] = Self.jsonTag
        
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let scripts = child.value as? [NativeScript] {
                    script["scripts"] = scripts.map { $0.toDict() }
                } else {
                    script[Self.jsonField] = child.value
                }
            }
        }
        return script
    }
}

class ScriptPubkey: NativeScript {
    override class var type: Int { return 0 }
    override class var jsonTag: String { return "sig" }
    override class var jsonField: String { return "keyHash" }

    let keyHash: VerificationKeyHash
    
    init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
}

class ScriptAll: NativeScript {
    override class var type: Int { return 1 }
    override class var jsonTag: String { return "all" }
    override class var jsonField: String { return "scripts" }

    let nativeScripts: [NativeScript]

    init(nativeScripts: [NativeScript]) {
        self.nativeScripts = nativeScripts
    }
}

class ScriptAny: NativeScript {
    override class var type: Int { return 2 }
    override class var jsonTag: String { return "any" }
    override class var jsonField: String { return "scripts" }

    let nativeScripts: [NativeScript]

    init(nativeScripts: [NativeScript]) {
        self.nativeScripts = nativeScripts
    }
}

class ScriptNofK: NativeScript {
    override class var type: Int { return 3 }
    override class var jsonTag: String { return "atLeast" }
    override class var jsonField: String { return "required" }

    let n: Int
    let nativeScripts: [NativeScript]

    init(n: Int, nativeScripts: [NativeScript]) {
        self.n = n
        self.nativeScripts = nativeScripts
    }
}

class InvalidBefore: NativeScript {
    override class var type: Int { return 4 }
    override class var jsonTag: String { return "after" }
    override class var jsonField: String { return "slot" }

    let before: Int

    init(before: Int) {
        self.before = before
    }
}

class InvalidHereAfter: NativeScript {
    override class var type: Int { return 5 }
    override class var jsonTag: String { return "before" }
    override class var jsonField: String { return "slot" }

    let after: Int

    init(after: Int) {
        self.after = after
    }
}
