import Foundation


class DatumOption: ArrayCBORSerializable {
    var type: Int
    var datum: Any

    init(datum: Any) {
        self.datum = datum
        if datum is DatumHash {
            self.type = 0
        } else {
            self.type = 1
        }
    }

    enum CodingKeys: String, CodingKey {
        case type = "_TYPE"
        case datum
    }

    func toPrimitive() -> [Any] {
        if type == 1 {
            return [type, CBORTag(value: 24, data: try! JSONEncoder().encode(datum))]
        } else {
            return [type, datum]
        }
    }

    static func fromPrimitive(_ values: [Any]) -> DatumOption {
        if values[0] as! Int == 0 {
            return DatumOption(datum: values[1] as! DatumHash)
        } else {
            let tag = values[1] as! CBORTag
            let v = try! JSONDecoder().decode(Any.self, from: tag.data)
            if v is CBORTag {
                return DatumOption(datum: RawPlutusData.fromPrimitive(v as! CBORTag))
            } else {
                return DatumOption(datum: v)
            }
        }
    }
}

class Script: ArrayCBORSerializable {
    var type: Int
    var script: Any

    init(script: Any) {
        self.script = script
        if script is NativeScript {
            self.type = 0
        } else if script is PlutusV1Script {
            self.type = 1
        } else {
            self.type = 2
        }
    }

    enum CodingKeys: String, CodingKey {
        case type = "_TYPE"
        case script
    }

    static func fromPrimitive(_ values: [Any]) -> Script {
        if values[0] as! Int == 0 {
            return Script(script: NativeScript.fromPrimitive(values[1] as! [Any]))
        } else {
            let scriptData = values[1] as! Data
            if values[0] as! Int == 1 {
                return Script(script: PlutusV1Script(scriptData))
            } else {
                return Script(script: PlutusV2Script(scriptData))
            }
        }
    }
}

class ScriptRef: CBORSerializable {
    var script: Script

    init(script: Script) {
        self.script = script
    }

    func toPrimitive() -> CBORTag {
        return CBORTag(value: 24, data: try! JSONEncoder().encode(script))
    }

    static func fromPrimitive(_ value: CBORTag) -> ScriptRef {
        let script = try! JSONDecoder().decode(Script.self, from: value.data)
        return ScriptRef(script: script)
    }
}
