import Foundation
import CBORCodable
import OrderedCollections

public struct VerificationKeyWitness: Serializable, TextEnvelopable {
    public static var TYPE: String { "TxWitness ConwayEra" }
    public static var DESCRIPTION: String { "Key Witness ShelleyEra" }

    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return _type } }
    public var description: String { get { return _description } }
    public var payload: Data { get { return _payload } }
    
    public var vkey: VerificationKeyType
    public var signature: Data
    
    enum CodingKeys: String, CodingKey {
        case vkey
        case signature
    }
    
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> VerificationKeyWitness {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid VerificationKeyWitness dict")
        }
        
        guard let vkeyPrimitive = dictValue[.string(CodingKeys.vkey.rawValue)],
              case let .string(vkeyHex) = vkeyPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid vkey in VerificationKeyWitness")
        }
        guard let vkeyData = Data(hexString: vkeyHex) else {
            throw CardanoCoreError.deserializeError("Invalid hex string for vkey in VerificationKeyWitness")
        }
        let vkey = try VerificationKeyType(from: .bytes(vkeyData))
        
        guard let signaturePrimitive = dictValue[.string(CodingKeys.signature.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing signature in VerificationKeyWitness")
        }
        
        let signatureData: Data
        switch signaturePrimitive {
        case .bytes(let data):
            signatureData = data
        case .string(let str):
            // Try base64 first, then hex
            if let data = Data(base64Encoded: str) {
                signatureData = data
            } else if let data = Data(hexString: str) {
                signatureData = data
            } else {
                throw CardanoCoreError.deserializeError("Invalid signature format in VerificationKeyWitness")
            }
        default:
            throw CardanoCoreError.deserializeError("Invalid signature type in VerificationKeyWitness")
        }
        
        return VerificationKeyWitness(vkey: vkey, signature: signatureData)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.vkey.rawValue)] = .string(vkey.payload.toHex)
        dict[.string(CodingKeys.signature.rawValue)] = .bytes(signature)
        return .orderedDict(dict)
    }

}

public struct TransactionWitnessSet: Serializable, Equatable {
    public var vkeyWitnesses: ListOrNonEmptyOrderedSet<VerificationKeyWitness>? {
        didSet { originalCBOR = nil }
    }
    public var nativeScripts: ListOrNonEmptyOrderedSet<NativeScript>? {
        didSet { originalCBOR = nil }
    }
    public var bootstrapWitness: ListOrNonEmptyOrderedSet<BootstrapWitness>? {
        didSet { originalCBOR = nil }
    }
    public var plutusV1Script: ListOrNonEmptyOrderedSet<PlutusV1Script>? {
        didSet { originalCBOR = nil }
    }
    public var plutusData: ListOrNonEmptyOrderedSet<PlutusData>? {
        didSet { originalCBOR = nil; originalPlutusDataCBOR = nil }
    }
    public var redeemers: Redeemers? {
        didSet { originalCBOR = nil; originalRedeemersCBOR = nil }
    }
    public var plutusV2Script: ListOrNonEmptyOrderedSet<PlutusV2Script>? {
        didSet { originalCBOR = nil }
    }
    public var plutusV3Script: ListOrNonEmptyOrderedSet<PlutusV3Script>? {
        didSet { originalCBOR = nil }
    }

    /// The exact bytes this witness set was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? = nil
    /// The bytes the witness datums (key 4) were decoded from, while they are
    /// unchanged.
    ///
    /// `script_data_hash` is taken over the datums and redeemers *as written*,
    /// and decoding cannot keep every detail of them — the width of an
    /// integer's header, for one — so adding a witness keeps these bytes
    /// rather than re-encoding them.
    public internal(set) var originalPlutusDataCBOR: Data? = nil
    /// The bytes the redeemers (key 5) were decoded from, while they are
    /// unchanged. See ``originalPlutusDataCBOR``.
    public internal(set) var originalRedeemersCBOR: Data? = nil

    /// The witness datums as `script_data_hash` takes them: as written while
    /// they are unchanged, otherwise freshly encoded; `nil` when there are none.
    public func plutusDataCBOR() throws -> Data? {
        guard let plutusData else { return nil }
        return try originalPlutusDataCBOR ?? CBOREncoder().encode(plutusData.toPrimitive())
    }

    /// The redeemers as `script_data_hash` takes them: as written while they
    /// are unchanged, otherwise freshly encoded; `nil` when there are none.
    public func redeemersCBOR() throws -> Data? {
        guard let redeemers else { return nil }
        return try originalRedeemersCBOR ?? CBOREncoder().encode(redeemers.toPrimitive())
    }

    public static func == (lhs: TransactionWitnessSet, rhs: TransactionWitnessSet) -> Bool {
        lhs.vkeyWitnesses == rhs.vkeyWitnesses && lhs.nativeScripts == rhs.nativeScripts
            && lhs.bootstrapWitness == rhs.bootstrapWitness
            && lhs.plutusV1Script == rhs.plutusV1Script && lhs.plutusData == rhs.plutusData
            && lhs.redeemers == rhs.redeemers && lhs.plutusV2Script == rhs.plutusV2Script
            && lhs.plutusV3Script == rhs.plutusV3Script
    }

    /// Hashes what `==` compares, leaving out the bytes it was read from.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(vkeyWitnesses)
        hasher.combine(plutusData)
        hasher.combine(redeemers)
    }

    /// Decodes a witness set, keeping the bytes of it and of its datums and
    /// redeemers.
    public static func fromCBOR(data: Data) throws -> TransactionWitnessSet {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after TransactionWitnessSet")
        }
        var witnessSet = try CBORDecoder().decode(TransactionWitnessSet.self, from: data)
        try witnessSet.keepBytes(scanner.bytes)
        return witnessSet
    }

    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// Records `bytes` as what this witness set was decoded from.
    mutating func keepBytes(_ bytes: Data) throws {
        let scanner = CBORItemScanner(bytes)
        for (key, value) in try scanner.entries(ofMapAt: scanner.untagged(at: 0)) {
            switch try scanner.unsignedInteger(at: key.lowerBound) {
                case UInt64(CodingKeys.plutusData.rawValue):
                    originalPlutusDataCBOR = scanner.bytes.subdata(in: value)
                case UInt64(CodingKeys.redeemers.rawValue):
                    originalRedeemersCBOR = scanner.bytes.subdata(in: value)
                default:
                    break
            }
        }
        originalCBOR = scanner.bytes
    }

    /// The bytes this witness set was decoded from while it is unchanged;
    /// otherwise a fresh encoding that keeps the datums and redeemers as
    /// written while they are unchanged.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        if let originalCBOR { return originalCBOR }
        guard case let .orderedDict(fields) = try toPrimitive() else {
            return try CBOREncoder().encode(self)
        }
        let encoder = CBOREncoder()
        var data = CBORItemScanner.definiteHeader(major: 5, count: fields.count)
        for (key, value) in fields {
            data.append(try encoder.encode(key))
            switch key {
                case .uint(UInt64(CodingKeys.plutusData.rawValue)) where originalPlutusDataCBOR != nil:
                    data.append(originalPlutusDataCBOR!)
                case .uint(UInt64(CodingKeys.redeemers.rawValue)) where originalRedeemersCBOR != nil:
                    data.append(originalRedeemersCBOR!)
                default:
                    data.append(try encoder.encode(value))
            }
        }
        return data
    }

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
        
        var stringValue: String {
            switch self {
            case .vkeyWitnesses: return "vkeyWitnesses"
            case .nativeScripts: return "nativeScripts"
            case .bootstrapWitness: return "bootstrapWitness"
            case .plutusV1Script: return "plutusV1Script"
            case .plutusData: return "plutusData"
            case .redeemers: return "redeemers"
            case .plutusV2Script: return "plutusV2Script"
            case .plutusV3Script: return "plutusV3Script"
            }
        }
    }
    
    public func isEmpty() -> Bool {
        return vkeyWitnesses == nil && nativeScripts == nil && bootstrapWitness == nil && plutusV1Script == nil && plutusData == nil && redeemers == nil && plutusV2Script == nil && plutusV3Script == nil
    }
    
    // MARK: - CBORSerializable

    /// Plutus data and redeemers are read as written, because adding a
    /// witness re-encodes the witness set and `script_data_hash` is taken over
    /// their bytes. Everything else is read in the usual form.
    public static var preservesEncoding: Bool { true }
    
    public init(from primitive: Primitive) throws {
        let dict: OrderedDictionary<Primitive, Primitive>
        switch primitive {
            case .orderedDict(let entries), .indefiniteDictionary(let entries):
                dict = entries
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionWitnessSet primitive")
        }
        
        func key(_ codingKey: CodingKeys) -> Primitive {
            return .uint(UInt64(codingKey.rawValue))
        }
        
        // vkeyWitnesses (key 0)
        if let vkeyWitnessesPrimitive = dict[key(CodingKeys.vkeyWitnesses)] {
            vkeyWitnesses = try ListOrNonEmptyOrderedSet<VerificationKeyWitness>(from: vkeyWitnessesPrimitive.normalized())
        } else {
            self.vkeyWitnesses = nil
        }
            
        
        // nativeScripts (key 1)
        if let nativeScriptsPrimitive = dict[key(CodingKeys.nativeScripts)] {
            nativeScripts = try ListOrNonEmptyOrderedSet<NativeScript>(from: nativeScriptsPrimitive.normalized())
        } else {
            self.nativeScripts = nil
        }
        
        // bootstrapWitness (key 2)
        if let bootstrapWitnessPrimitive = dict[key(CodingKeys.bootstrapWitness)] {
            bootstrapWitness = try ListOrNonEmptyOrderedSet<BootstrapWitness>(from: bootstrapWitnessPrimitive.normalized())
        } else {
            self.bootstrapWitness = nil
        }
        
        // plutusV1Script (key 3)
        if let plutusV1ScriptPrimitive = dict[key(CodingKeys.plutusV1Script)] {
            plutusV1Script = try ListOrNonEmptyOrderedSet<PlutusV1Script>(from: plutusV1ScriptPrimitive.normalized())
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
            plutusV2Script = try ListOrNonEmptyOrderedSet<PlutusV2Script>(from: plutusV2ScriptPrimitive.normalized())
        } else {
            self.plutusV2Script = nil
        }
        
        // plutusV3Script (key 7)
        if let plutusV3ScriptPrimitive = dict[key(CodingKeys.plutusV3Script)] {
            plutusV3Script = try ListOrNonEmptyOrderedSet<PlutusV3Script>(from: plutusV3ScriptPrimitive.normalized())
        } else {
            self.plutusV3Script = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        // In ascending key order, so a witness set always encodes the same way.
        var dict = OrderedDictionary<Primitive, Primitive>()
        func put<T: CBORSerializable>(_ key: CodingKeys, _ value: T?) throws {
            if let value { dict[.uint(UInt64(key.rawValue))] = try value.toPrimitive() }
        }
        try put(.vkeyWitnesses, vkeyWitnesses)
        try put(.nativeScripts, nativeScripts)
        try put(.bootstrapWitness, bootstrapWitness)
        try put(.plutusV1Script, plutusV1Script)
        try put(.plutusData, plutusData)
        try put(.redeemers, redeemers)
        try put(.plutusV2Script, plutusV2Script)
        try put(.plutusV3Script, plutusV3Script)
        return .orderedDict(dict)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> TransactionWitnessSet {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid TransactionWitnessSet dict format")
        }
        var vkeyWitnesses: ListOrNonEmptyOrderedSet<VerificationKeyWitness>? = nil
        if let vkeyWitnessesPrimitive = orderedDict[.string(CodingKeys.vkeyWitnesses.stringValue)] {
            vkeyWitnesses = try ListOrNonEmptyOrderedSet<VerificationKeyWitness>.fromDict(vkeyWitnessesPrimitive)
        }
        
        var nativeScripts: ListOrNonEmptyOrderedSet<NativeScript>? = nil
        if let nativeScriptsPrimitive = orderedDict[.string(CodingKeys.nativeScripts.stringValue)] {
            nativeScripts = try ListOrNonEmptyOrderedSet<NativeScript>.fromDict(nativeScriptsPrimitive)
        }
        
        var bootstrapWitness: ListOrNonEmptyOrderedSet<BootstrapWitness>? = nil
        if let bootstrapWitnessPrimitive = orderedDict[.string(CodingKeys.bootstrapWitness.stringValue)] {
            bootstrapWitness = try ListOrNonEmptyOrderedSet<BootstrapWitness>.fromDict(bootstrapWitnessPrimitive)
        }
        
        var plutusV1Script: ListOrNonEmptyOrderedSet<PlutusV1Script>? = nil
        if let plutusV1ScriptPrimitive = orderedDict[.string(CodingKeys.plutusV1Script.stringValue)] {
            plutusV1Script = try ListOrNonEmptyOrderedSet<PlutusV1Script>.fromDict(plutusV1ScriptPrimitive)
        }
        
        var plutusData: ListOrNonEmptyOrderedSet<PlutusData>? = nil
        if let plutusDataPrimitive = orderedDict[.string(CodingKeys.plutusData.stringValue)] {
            plutusData = try ListOrNonEmptyOrderedSet<PlutusData>.fromDict(plutusDataPrimitive)
        }
        
        var redeemers: Redeemers? = nil
        if let redeemersPrimitive = orderedDict[.string(CodingKeys.redeemers.stringValue)] {
            redeemers = try Redeemers.fromDict(redeemersPrimitive)
        }
        
        var plutusV2Script: ListOrNonEmptyOrderedSet<PlutusV2Script>? = nil
        if let plutusV2ScriptPrimitive = orderedDict[.string(CodingKeys.plutusV2Script.stringValue)] {
            plutusV2Script = try ListOrNonEmptyOrderedSet<PlutusV2Script>.fromDict(plutusV2ScriptPrimitive)
        }
        
        var plutusV3Script: ListOrNonEmptyOrderedSet<PlutusV3Script>? = nil
        if let plutusV3ScriptPrimitive = orderedDict[.string(CodingKeys.plutusV3Script.stringValue)] {
            plutusV3Script = try ListOrNonEmptyOrderedSet<PlutusV3Script>.fromDict(plutusV3ScriptPrimitive)
        }
        
        return TransactionWitnessSet(
            vkeyWitnesses: vkeyWitnesses,
            nativeScripts: nativeScripts,
            bootstrapWitness: bootstrapWitness,
            plutusV1Script: plutusV1Script,
            plutusV2Script: plutusV2Script,
            plutusData: plutusData,
            redeemers: redeemers,
            plutusV3Script: plutusV3Script
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedCollections.OrderedDictionary<Primitive, Primitive>()
        
        // Helper to convert ListOrNonEmptyOrderedSet to list of primitives for JSON
        func listOrSetToList<T: CBORSerializable>(_ value: ListOrNonEmptyOrderedSet<T>) throws -> Primitive {
            // Convert to list representation for JSON (sets don't exist in JSON)
            let elements = value.asList
            return .list(try elements.map { try $0.toPrimitive() })
        }
        
        if let vkeyWitnesses = vkeyWitnesses {
            dict[.string(CodingKeys.vkeyWitnesses.stringValue)] = try vkeyWitnesses.toDict()
        }
        
        if let nativeScripts = nativeScripts {
            dict[.string(CodingKeys.nativeScripts.stringValue)] = try nativeScripts.toDict()
        }
        
        if let bootstrapWitness = bootstrapWitness {
            dict[.string(CodingKeys.bootstrapWitness.stringValue)] = try bootstrapWitness.toDict()
        }
        
        if let plutusV1Script = plutusV1Script {
            dict[.string(CodingKeys.plutusV1Script.stringValue)] = try plutusV1Script.toDict()
        }
        
        if let plutusData = plutusData {
            dict[.string(CodingKeys.plutusData.stringValue)] = try plutusData.toDict()
        }
        
        if let redeemers = redeemers {
            dict[.string(CodingKeys.redeemers.stringValue)] = try redeemers.toDict()
        }
        
        if let plutusV2Script = plutusV2Script {
            dict[.string(CodingKeys.plutusV2Script.stringValue)] = try plutusV2Script.toDict()
        }
        
        if let plutusV3Script = plutusV3Script {
            dict[.string(CodingKeys.plutusV3Script.stringValue)] = try plutusV3Script.toDict()
        }
        
        return .orderedDict(dict)
    }

}
