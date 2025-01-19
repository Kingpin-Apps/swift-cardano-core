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
                script = .nativeScript(try container.decode(NativeScripts.self))
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
}
