import Foundation
import PotentCBOR

struct DatumOption: Codable {
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
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        type = try container.decode(Int.self)
        if type == 0 {
            datum = try container.decode(DatumHash.self)
        } else {
            datum = try container.decode(RawPlutusData.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(type)
        if type == 1 {
            let cborTag = CBORTag(tag: 24, value: CBOR.fromAny(datum))
            try container.encode(cborTag)
        } else {
            try container.encode(datum as! DatumOption)
        }
    }

//    func toPrimitive() throws -> [Any] {
//        if type == 1 {
//            return [
//                type,
//                CBORTag(
//                    tag: 24,
//                    value: try CBORSerialization.data(from: CBOR.fromAny(datum))
//                )
//            ]
//        } else {
//            return [type, datum]
//        }
//    }

//    static func fromPrimitive<T>(_ values: Any) throws -> T {
//        guard let values = values as? [Any] else {
//            throw CardanoCoreError
//                .valueError("Invalid DatumOption data: \(values)")
//        }
//        
//        if values[0] as! Int == 0 {
//            return DatumOption(datum: values[1] as! DatumHash) as! T
//        } else {
//            let tag = values[1] as! CBORTag
//            let v = try CBORSerialization.cbor(from: tag.value)
//            if case let CBOR.tagged(_, v) = v {
//                return DatumOption(
//                    datum: try RawPlutusData.fromPrimitive(v)
//                ) as! T
//            } else {
//                return DatumOption(datum: v) as! T
//            }
//        }
//    }
}

struct Script: Codable {
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
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        type = try container.decode(Int.self)
        
        switch type {
            case 0:
                script = .nativeScript(try container.decode(NativeScript.self))
            case 1:
                script = .plutusV1Script(try container.decode(Data.self))
            case 2:
                script = .plutusV2Script(try container.decode(Data.self))
            case 3:
                script = .plutusV3Script(try container.decode(Data.self))
            default:
                throw CardanoCoreError
                    .valueError("Invalid Script type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(type)
        switch script {
            case .nativeScript(let script):
                try container.encode(script)
            case .plutusV1Script(let script):
                try container.encode(script)
            case .plutusV2Script(let script):
                try container.encode(script)
            case .plutusV3Script(let script):
                try container.encode(script)
        }
    }

//    static func fromPrimitive<T>(_ values: Any) throws -> T {
//        guard let values = values as? [Any] else {
//            throw CardanoCoreError
//                .valueError("Invalid Script data: \(values)")
//        }
//        
//        if values[0] as! Int == 0 {
//            return Script(script: try NativeScript.fromPrimitive(values[1] as! [Any])) as! T
//        } else {
//            let scriptData = values[1] as! Data
//            if values[0] as! Int == 1 {
//                return Script(script: .plutusV1Script(scriptData)) as! T
//            } else if values[0] as! Int == 2 {
//                return Script(script: .plutusV2Script(scriptData)) as! T
//            } else if values[0] as! Int == 3 {
//                return Script(script: .plutusV3Script(scriptData)) as! T
//            }
//        }
//        throw CardanoCoreError
//            .valueError("Invalid Script data: \(values)")
//    }
}

struct ScriptRef: Codable {
    var script: Script

    init(script: Script) {
        self.script = script
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(CBORTag.self)
        
        guard tag.tag == 24 else {
            throw CardanoCoreError
                .valueError("Invalid ScriptRef tag: \(tag.tag)")
        }
        
        script = try container.decode(Script.self)
    }

    func encode(to encoder: Encoder) throws {
        let cborTag = CBORTag(
            tag: 24,
            value: CBOR.fromAny(script)
        )
        
        var container = encoder.unkeyedContainer()
        try container.encode(cborTag)
    }

//    func toShallowPrimitive() throws -> Any {
//        return CBORTag(
//            tag: 24,
//            value: CBOR.fromAny(script)
//        )
//    }
//
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let value = value as? CBORTag else {
//            throw CardanoCoreError
//                .valueError("Invalid ScriptRef data: \(value)")
//        }
//        
//        let script: Script = try Script.fromPrimitive(
//            try CBORSerialization.cbor(from: value.value)
//        )
//        return ScriptRef(script: script) as! T
//    }
}
