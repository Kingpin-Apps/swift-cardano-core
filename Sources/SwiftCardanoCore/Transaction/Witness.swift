import Foundation

public struct VerificationKeyWitness: Codable, Equatable, Hashable {
    public var vkey: VerificationKeyType
    public var signature: Data
    
    public init(vkey: VerificationKeyType, signature: Data) {
        self.vkey = vkey
        self.signature = signature
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        vkey = try container.decode(VerificationKeyType.self)
        signature = try container.decode(Data.self)
    }

    public func encode(to encoder: Encoder) throws {
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

public struct TransactionWitnessSet: Codable, Equatable, Hashable {
    public let vkeyWitnesses: [VerificationKeyWitness]?
    public let nativeScripts: [NativeScripts]?
    public let bootstrapWitness: [BootstrapWitness]?
    public let plutusV1Script: [PlutusV1Script]?
    public let plutusData: [RawPlutusData]?
    public let redeemers: [Redeemer]?
    public let plutusV2Script: [PlutusV2Script]?
    public let plutusV3Script: [PlutusV3Script]?

    public init(
        vkeyWitnesses: [VerificationKeyWitness]? = nil,
        nativeScripts: [NativeScripts]? = nil,
        bootstrapWitness: [BootstrapWitness]? = nil,
        plutusV1Script: [PlutusV1Script]? = nil,
        plutusV2Script: [PlutusV2Script]? = nil,
        plutusData: [RawPlutusData]? = nil,
        redeemers: [Redeemer]? = nil,
        plutusV3Script: [PlutusV3Script]? = nil
    ) {
        self.vkeyWitnesses = vkeyWitnesses
        self.nativeScripts = nativeScripts
        self.bootstrapWitness = bootstrapWitness
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusData = plutusData
        self.redeemers = redeemers
        self.plutusV3Script = plutusV3Script
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
    
    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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
    
    public func isEmpty() -> Bool {
        return vkeyWitnesses == nil && nativeScripts == nil && bootstrapWitness == nil && plutusV1Script == nil && plutusData == nil && redeemers == nil && plutusV2Script == nil && plutusV3Script == nil
    }
}
