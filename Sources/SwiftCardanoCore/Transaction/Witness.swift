import Foundation

enum VerificationKeyType: Codable {
    case extendedVerificationKey(any ExtendedVerificationKey)
    case verificationKey(any VerificationKey)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        if data.count == 64 {
            self = .verificationKey(VKey(payload: data))
        } else {
            self = .extendedVerificationKey(ExtendedVKey(payload: data))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .extendedVerificationKey(let key):
                try container.encode(key)
            case .verificationKey(let key):
                try container.encode(key)
        }
    }
}

struct VerificationKeyWitness: Codable {
    var vkey: VerificationKeyType
    var signature: Data
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        vkey = try container.decode(VerificationKeyType.self)
        signature = try container.decode(Data.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        switch vkey {
            case .extendedVerificationKey(let key):
                try container.encode(key)
            case .verificationKey(let key):
                try container.encode(key)
        }
        
        try container.encode(signature)
    }
}

struct TransactionWitnessSet: Codable {

    var vkeyWitnesses: [VerificationKeyWitness]?
    var nativeScripts: [NativeScripts]?
    var bootstrapWitness: [BootstrapWitness]?
    var plutusV1Script: [PlutusV1Script]?
    var plutusData: [RawPlutusData]?
    var redeemers: [Redeemer]?
    var plutusV2Script: [PlutusV2Script]?
    var plutusV3Script: [PlutusV3Script]?

    init(
        vkeyWitnesses: [VerificationKeyWitness]? = nil,
        nativeScripts: [NativeScripts]? = nil,
        bootstrapWitness: [BootstrapWitness]? = nil,
        plutusV1Script: [PlutusV1Script]? = nil,
        plutusV2Script: [PlutusV2Script]? = nil,
        plutusData: [RawPlutusData]? = nil,
        redeemers: [Redeemer]? = nil
    ) {
        self.vkeyWitnesses = vkeyWitnesses
        self.nativeScripts = nativeScripts
        self.bootstrapWitness = bootstrapWitness
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusData = plutusData
        self.redeemers = redeemers
    }

    enum CodingKeys: Int, CodingKey {
        case vkeyWitnesses = 0
        case nativeScripts = 1
        case bootstrapWitness = 2
        case plutusV1Script = 3
        case plutusData = 4
        case redeemers = 5
        case plutusV2Script = 6
        case plutusV3Script = 7
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vkeyWitnesses = try container.decodeIfPresent([VerificationKeyWitness].self, forKey: .vkeyWitnesses)
        nativeScripts = try container.decodeIfPresent([NativeScripts].self, forKey: .nativeScripts)
        bootstrapWitness = try container.decodeIfPresent([BootstrapWitness].self, forKey: .bootstrapWitness)
        plutusV1Script = try container.decodeIfPresent([PlutusV1Script].self, forKey: .plutusV1Script)
        plutusData = try container.decodeIfPresent([RawPlutusData].self, forKey: .plutusData)
        redeemers = try container.decodeIfPresent([Redeemer].self, forKey: .redeemers)
        plutusV2Script = try container.decodeIfPresent([PlutusV2Script].self, forKey: .plutusV2Script)
        plutusV3Script = try container.decodeIfPresent([PlutusV3Script].self, forKey: .plutusV3Script)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(vkeyWitnesses, forKey: .vkeyWitnesses)
        try container.encodeIfPresent(nativeScripts, forKey: .nativeScripts)
        try container.encodeIfPresent(bootstrapWitness, forKey: .bootstrapWitness)
        try container.encodeIfPresent(plutusV1Script, forKey: .plutusV1Script)
        try container.encodeIfPresent(plutusData, forKey: .plutusData)
        try container.encodeIfPresent(redeemers, forKey: .redeemers)
        try container.encodeIfPresent(plutusV2Script, forKey: .plutusV2Script)
        try container.encodeIfPresent(plutusV3Script, forKey: .plutusV3Script)
    }

//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        func getVkeyWitnesses(_ data: Any?) throws -> [VerificationKeyWitness]? {
//            guard let data = data as? [Any] else { return nil }
//            return try data
//                .map { try VerificationKeyWitness.fromPrimitive($0 as! [Any]) }
//        }
//
//        func getNativeScripts(_ data: Any?) throws -> [NativeScript]? {
//            guard let data = data as? [Any] else { return nil }
//            return try data.map { try NativeScript.fromPrimitive($0 as! [Any]) }
//        }
//
//        func getPlutusV1Scripts(_ data: Any?) -> [PlutusV1Script]? {
//            guard let data = data as? [Data] else { return nil }
//            return data.map { PlutusV1Script($0) }
//        }
//
//        func getPlutusV2Scripts(_ data: Any?) -> [PlutusV2Script]? {
//            guard let data = data as? [Data] else { return nil }
//            return data.map { PlutusV2Script($0) }
//        }
//
//        func getRedeemers(_ data: Any?) throws -> [Redeemer]? {
//            guard let data = data as? [Any] else { return nil }
//            return try data.map { try Redeemer.fromPrimitive($0 as! [Any]) }
//        }
//
//        if let values = value as? [String: Any] {
//            return TransactionWitnessSet(
//                vkeyWitnesses: try getVkeyWitnesses(values["0"]),
//                nativeScripts: try getNativeScripts(values["1"]),
//                bootstrapWitness: values["2"] as? [Any],
//                plutusV1Script: getPlutusV1Scripts(values["3"]),
//                plutusV2Script: getPlutusV2Scripts(values["6"]),
//                plutusData: values["4"] as? [RawPlutusData],
//                redeemers: try getRedeemers(values["5"])
//            ) as! T
//        } else if let values = value as? [Any] {
//            let dict = Dictionary(uniqueKeysWithValues: values.enumerated().map { (String($0.offset), $0.element) })
//            return TransactionWitnessSet(
//                vkeyWitnesses: try getVkeyWitnesses(dict["0"]),
//                nativeScripts: try getNativeScripts(dict["1"]),
//                bootstrapWitness: dict["2"] as? [Any],
//                plutusV1Script: getPlutusV1Scripts(dict["3"]),
//                plutusV2Script: getPlutusV2Scripts(dict["6"]),
//                plutusData: dict["4"] as? [RawPlutusData],
//                redeemers: try getRedeemers(dict["5"])
//            ) as! T
//        }
//        
//        throw CardanoCoreError.valueError("Invalid TransactionWitnessSet data: \(value)")
//    }
}
