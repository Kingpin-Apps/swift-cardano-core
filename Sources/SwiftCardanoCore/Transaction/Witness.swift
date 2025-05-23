import Foundation
import PotentCBOR

public struct VerificationKeyWitness: PayloadCBORSerializable, Equatable, Hashable {
    public var vkey: VerificationKeyType
    public var signature: Data
    
    public static var TYPE: String { "TxWitness ConwayEra" }
    public static var DESCRIPTION: String { "Key Witness ShelleyEra" }

    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public init(payload: Data, type: String?, description: String?) {
//        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
//            self._payload = payloadData
//        } else {
//            self._payload = payload
//        }
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        self.vkey = cbor.vkey
        self.signature = cbor.signature
    }
    
    public init(vkey: VerificationKeyType, signature: Data) {
        self.vkey = vkey
        self.signature = signature
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        try! CBOREncoder().encode(vkey).toCBOR,
                        try! CBOREncoder().encode(signature).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let vkey = try container.decode(VerificationKeyType.self)
        let signature = try container.decode(Data.self)
        
        self.init(vkey: vkey, signature: signature)
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

public struct TransactionWitnessSet<T: Codable & Hashable>: CBORSerializable, Equatable, Hashable {
    public var vkeyWitnesses: NonEmptyOrderedCBORSet<VerificationKeyWitness>?
    public var nativeScripts: NonEmptyOrderedCBORSet<NativeScript>?
    public var bootstrapWitness: NonEmptyOrderedCBORSet<BootstrapWitness>?
    public var plutusV1Script: NonEmptyOrderedCBORSet<PlutusV1Script>?
    public var plutusData: NonEmptyOrderedCBORSet<RawPlutusData>?
    public var redeemers: Redeemers<T>?
    public var plutusV2Script: NonEmptyOrderedCBORSet<PlutusV2Script>?
    public var plutusV3Script: NonEmptyOrderedCBORSet<PlutusV3Script>?

    public init(
        vkeyWitnesses: NonEmptyOrderedCBORSet<VerificationKeyWitness>? = nil,
        nativeScripts: NonEmptyOrderedCBORSet<NativeScript>? = nil,
        bootstrapWitness: NonEmptyOrderedCBORSet<BootstrapWitness>? = nil,
        plutusV1Script: NonEmptyOrderedCBORSet<PlutusV1Script>? = nil,
        plutusV2Script: NonEmptyOrderedCBORSet<PlutusV2Script>? = nil,
        plutusData: NonEmptyOrderedCBORSet<RawPlutusData>? = nil,
        redeemers: Redeemers<T>? = nil,
        plutusV3Script: NonEmptyOrderedCBORSet<PlutusV3Script>? = nil
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
        vkeyWitnesses = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<VerificationKeyWitness>.self, forKey: .vkeyWitnesses
        )
        nativeScripts = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<NativeScript>.self, forKey: .nativeScripts
        )
        bootstrapWitness = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<BootstrapWitness>.self, forKey: .bootstrapWitness
        )
        plutusV1Script = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<PlutusV1Script>.self, forKey: .plutusV1Script
        )
        plutusData = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<RawPlutusData>.self, forKey: .plutusData
        )
        redeemers = try container.decodeIfPresent(Redeemers<T>.self, forKey: .redeemers)
        plutusV2Script = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<PlutusV2Script>.self, forKey: .plutusV2Script
        )
        plutusV3Script = try container.decodeIfPresent(
            NonEmptyOrderedCBORSet<PlutusV3Script>.self, forKey: .plutusV3Script
        )
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
