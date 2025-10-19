import Foundation
import PotentCBOR

public struct VerificationKeyWitness: PayloadCBORSerializable {
    public var vkey: VerificationKeyType
    public var signature: Data
    
    public static var TYPE: String { "TxWitness ConwayEra" }
    public static var DESCRIPTION: String { "Key Witness ShelleyEra" }

    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public init(payload: Data, type: String?, description: String?) {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid VerificationKeyWitness primitive")
        }
        
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError("VerificationKeyWitness requires exactly 2 elements")
        }
        
        // vkey (VerificationKeyType)
        self.vkey = try VerificationKeyType(from: elements[0])
        
        // signature (Data)
        guard case let .bytes(signatureData) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid signature in VerificationKeyWitness")
        }
        self.signature = signatureData
        
        // Initialize the PayloadCBORSerializable properties
        self._payload = try! CBORSerialization.data(from:
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
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        
        // vkey (VerificationKeyType)
        elements.append(try vkey.toPrimitive())
        
        // signature (Data)
        elements.append(.bytes(signature))
        
        return .list(elements)
    }
}

public struct TransactionWitnessSet: CBORSerializable {
    public var vkeyWitnesses: ListOrNonEmptyOrderedSet<VerificationKeyWitness>?
    public var nativeScripts: ListOrNonEmptyOrderedSet<NativeScript>?
    public var bootstrapWitness: ListOrNonEmptyOrderedSet<BootstrapWitness>?
    public var plutusV1Script: ListOrNonEmptyOrderedSet<PlutusV1Script>?
    public var plutusData: ListOrNonEmptyOrderedSet<PlutusData>?
    public var redeemers: Redeemers?
    public var plutusV2Script: ListOrNonEmptyOrderedSet<PlutusV2Script>?
    public var plutusV3Script: ListOrNonEmptyOrderedSet<PlutusV3Script>?

    public init(
        vkeyWitnesses: ListOrNonEmptyOrderedSet<VerificationKeyWitness>? = nil,
        nativeScripts: ListOrNonEmptyOrderedSet<NativeScript>? = nil,
        bootstrapWitness: ListOrNonEmptyOrderedSet<BootstrapWitness>? = nil,
        plutusV1Script: ListOrNonEmptyOrderedSet<PlutusV1Script>? = nil,
        plutusV2Script: ListOrNonEmptyOrderedSet<PlutusV2Script>? = nil,
        plutusData: ListOrNonEmptyOrderedSet<PlutusData>? = nil,
        redeemers: Redeemers? = nil,
        plutusV3Script: ListOrNonEmptyOrderedSet<PlutusV3Script>? = nil
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
    
    public func isEmpty() -> Bool {
        return vkeyWitnesses == nil && nativeScripts == nil && bootstrapWitness == nil && plutusV1Script == nil && plutusData == nil && redeemers == nil && plutusV2Script == nil && plutusV3Script == nil
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionWitnessSet primitive")
        }
        
        func key(_ codingKey: CodingKeys) -> Primitive {
            return .uint(UInt(codingKey.rawValue))
        }
        
        // vkeyWitnesses (key 0)
        if let vkeyWitnessesPrimitive = dict[key(CodingKeys.vkeyWitnesses)] {
            vkeyWitnesses = try ListOrNonEmptyOrderedSet<VerificationKeyWitness>(from: vkeyWitnessesPrimitive)
        } else {
            self.vkeyWitnesses = nil
        }
            
        
        // nativeScripts (key 1)
        if let nativeScriptsPrimitive = dict[key(CodingKeys.nativeScripts)] {
            nativeScripts = try ListOrNonEmptyOrderedSet<NativeScript>(from: nativeScriptsPrimitive)
        } else {
            self.nativeScripts = nil
        }
        
        // bootstrapWitness (key 2)
        if let bootstrapWitnessPrimitive = dict[key(CodingKeys.bootstrapWitness)] {
            bootstrapWitness = try ListOrNonEmptyOrderedSet<BootstrapWitness>(from: bootstrapWitnessPrimitive)
        } else {
            self.bootstrapWitness = nil
        }
        
        // plutusV1Script (key 3)
        if let plutusV1ScriptPrimitive = dict[key(CodingKeys.plutusV1Script)] {
            plutusV1Script = try ListOrNonEmptyOrderedSet<PlutusV1Script>(from: plutusV1ScriptPrimitive)
        } else {
            self.plutusV1Script = nil
        }
        
        // plutusData (key 4)
        if let plutusDataPrimitive = dict[key(CodingKeys.plutusData)] {
            plutusData = try ListOrNonEmptyOrderedSet<PlutusData>(from: plutusDataPrimitive)
        } else {
            self.plutusData = nil
        }
        
        // redeemers (key 5)
        if let redeemersPrimitive = dict[key(CodingKeys.redeemers)] {
            self.redeemers = try Redeemers(from: redeemersPrimitive)
        } else {
            self.redeemers = nil
        }
        
        // plutusV2Script (key 6)
        if let plutusV2ScriptPrimitive = dict[key(CodingKeys.plutusV2Script)] {
            plutusV2Script = try ListOrNonEmptyOrderedSet<PlutusV2Script>(from: plutusV2ScriptPrimitive)
        } else {
            self.plutusV2Script = nil
        }
        
        // plutusV3Script (key 7)
        if let plutusV3ScriptPrimitive = dict[key(CodingKeys.plutusV3Script)] {
            plutusV3Script = try ListOrNonEmptyOrderedSet<PlutusV3Script>(from: plutusV3ScriptPrimitive)
        } else {
            self.plutusV3Script = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]
        
        if let vkeyWitnesses = vkeyWitnesses {
            dict[.int(CodingKeys.vkeyWitnesses.rawValue)] = try vkeyWitnesses.toPrimitive()
        }
        
        if let nativeScripts = nativeScripts {
            dict[.int(CodingKeys.nativeScripts.rawValue)] = try nativeScripts.toPrimitive()
        }
        
        if let bootstrapWitness = bootstrapWitness {
            dict[.int(CodingKeys.bootstrapWitness.rawValue)] = try bootstrapWitness.toPrimitive()
        }
        
        if let plutusV1Script = plutusV1Script {
            dict[.int(CodingKeys.plutusV1Script.rawValue)] = try plutusV1Script.toPrimitive()
        }
        
        if let plutusData = plutusData {
            dict[.int(CodingKeys.plutusData.rawValue)] = try plutusData.toPrimitive()
        }
        
        if let redeemers = redeemers {
            dict[.int(CodingKeys.redeemers.rawValue)] = try redeemers.toPrimitive()
        }
        
        if let plutusV2Script = plutusV2Script {
            dict[.int(CodingKeys.plutusV2Script.rawValue)] = try plutusV2Script.toPrimitive()
        }
        
        if let plutusV3Script = plutusV3Script {
            dict[.int(CodingKeys.plutusV3Script.rawValue)] = try plutusV3Script.toPrimitive()
        }
        
        return .dict(dict)
    }
}
