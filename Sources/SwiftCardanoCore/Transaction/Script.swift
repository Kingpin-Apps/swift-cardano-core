import Foundation
import PotentCBOR

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

    func toPrimitive() throws -> [Any] {
        if type == 1 {
            return [
                type,
                CBORTag(
                    tag: 24,
                    value: try CBORSerialization.data(from: CBOR.fromAny(datum))
                )
            ]
        } else {
            return [type, datum]
        }
    }

    static func fromPrimitive<T>(_ values: Any) throws -> T {
        guard let values = values as? [Any] else {
            throw CardanoCoreError
                .valueError("Invalid DatumOption data: \(values)")
        }
        
        if values[0] as! Int == 0 {
            return DatumOption(datum: values[1] as! DatumHash) as! T
        } else {
            let tag = values[1] as! CBORTag
            let v = try CBORSerialization.cbor(from: tag.value as! Data)
            if case let CBOR.tagged(_, v) = v {
                return DatumOption(
                    datum: try RawPlutusData.fromPrimitive(v)
                ) as! T
            } else {
                return DatumOption(datum: v) as! T
            }
        }
    }
}

class Script: ArrayCBORSerializable {
    var type: Int
    var script: ScriptType

    init(script: ScriptType) {
        self.script = script
        switch script {
            case .nativeScript:
                self.type = 0
            case .plutusV1Script:
                self.type = 1
            case .plutusV2Script:
                self.type = 2
            case .plutusV3Script(_):
                self.type = 3
        }
    }

    static func fromPrimitive<T>(_ values: Any) throws -> T {
        guard let values = values as? [Any] else {
            throw CardanoCoreError
                .valueError("Invalid Script data: \(values)")
        }
        
        if values[0] as! Int == 0 {
            return Script(script: try NativeScript.fromPrimitive(values[1] as! [Any])) as! T
        } else {
            let scriptData = values[1] as! Data
            if values[0] as! Int == 1 {
                return Script(script: .plutusV1Script(scriptData)) as! T
            } else if values[0] as! Int == 2 {
                return Script(script: .plutusV2Script(scriptData)) as! T
            } else if values[0] as! Int == 3 {
                return Script(script: .plutusV3Script(scriptData)) as! T
            }
        }
        throw CardanoCoreError
            .valueError("Invalid Script data: \(values)")
    }
}

class ScriptRef: CBORSerializable {
    var script: Script

    init(script: Script) {
        self.script = script
    }

    func toShallowPrimitive() throws -> Any {
        return CBORTag(
            tag: 24,
            value: try script.toCBOR()
        )
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let value = value as? CBORTag else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef data: \(value)")
        }
        
        let script: Script = try Script.fromPrimitive(
            try CBORSerialization.cbor(from: value.value as! Data)
        )
        return ScriptRef(script: script) as! T
    }
}
