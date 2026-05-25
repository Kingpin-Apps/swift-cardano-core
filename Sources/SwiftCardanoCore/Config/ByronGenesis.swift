import Foundation

/// Represents the Byron genesis configuration
public struct ByronGenesis: JSONLoadable {
    /// Distribution of Ada vouchers
    public let avvmDistr: [String: String]
    /// Block version data configuration
    public let blockVersionData: BlockVersionData
    /// FTS seed value
    public let ftsSeed: String?
    /// Protocol constants
    public let protocolConsts: ProtocolConsts
    /// Genesis start time (POSIX timestamp; Int64 to avoid Y2038 overflow on 32-bit platforms)
    public let startTime: Int64
    /// Boot stakeholders
    public let bootStakeholders: [String: Int]
    /// Heavy delegation certificates
    public let heavyDelegation: [String: HeavyDelegation]
    /// Non-AVVM balances
    public let nonAvvmBalances: [String: String]
    /// VSS certificates
    public let vssCerts: [String: VSSCert]?

    public init(
        avvmDistr: [String: String],
        blockVersionData: BlockVersionData,
        ftsSeed: String?,
        protocolConsts: ProtocolConsts,
        startTime: Int64,
        bootStakeholders: [String: Int],
        heavyDelegation: [String: HeavyDelegation],
        nonAvvmBalances: [String: String],
        vssCerts: [String: VSSCert]?
    ) {
        self.avvmDistr = avvmDistr
        self.blockVersionData = blockVersionData
        self.ftsSeed = ftsSeed
        self.protocolConsts = protocolConsts
        self.startTime = startTime
        self.bootStakeholders = bootStakeholders
        self.heavyDelegation = heavyDelegation
        self.nonAvvmBalances = nonAvvmBalances
        self.vssCerts = vssCerts
    }
}

/// Block version data configuration
public struct BlockVersionData: Codable, Equatable, Hashable {
    public let heavyDelThd: String
    public let maxBlockSize: String
    public let maxHeaderSize: String
    public let maxProposalSize: String
    public let maxTxSize: String
    public let mpcThd: String
    public let scriptVersion: Int
    public let slotDuration: String
    public let softforkRule: SoftforkRule
    public let txFeePolicy: TxFeePolicy
    public let unlockStakeEpoch: String
    public let updateImplicit: String
    public let updateProposalThd: String
    public let updateVoteThd: String
}

/// Softfork rule configuration
public struct SoftforkRule: Codable, Equatable, Hashable {
    public let initThd: String
    public let minThd: String
    public let thdDecrement: String
}

/// Transaction fee policy
public struct TxFeePolicy: Codable, Equatable, Hashable {
    public let multiplier: String
    public let summand: String
}

/// Protocol constants
public struct ProtocolConsts: Codable, Equatable, Hashable {
    public let k: Int
    public let protocolMagic: Int
    public let vssMaxTTL: Int?
    public let vssMinTTL: Int?
}

/// Heavy delegation certificate
public struct HeavyDelegation: Codable, Equatable, Hashable {
    public let cert: String
    public let delegatePk: String
    public let issuerPk: String
    public let omega: Int
}

/// VSS certificate
public struct VSSCert: Codable, Equatable, Hashable {
    public let expiryEpoch: Int
    public let signature: String
    public let signingKey: String
    public let vssKey: String
}

// MARK: - CBOR
//
// The Byron genesis CBOR from the node uses a CBOR map with string keys
// (matching the JSON field names), because Byron uses its own legacy encoding.
// The `GetGenesisConfig` query for Byron era is rarely used in practice;
// this implementation handles the common CBOR map encoding.
//
// NOTE: Verify against live node output for Byron-era nodes.

extension ByronGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case avvmDistr, blockVersionData, ftsSeed, protocolConsts, startTime
        case bootStakeholders, heavyDelegation, nonAvvmBalances, vssCerts
    }

    // Custom Codable that routes JSON loads (genesis JSON files) through a
    // keyed container, while CBOR encodes/decodes via Primitive. Without this,
    // CBORSerializable's default init(from:) routes JSON through Primitive,
    // which expects a JSON-string-containing-JSON.
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                avvmDistr:        try c.decode([String: String].self, forKey: .avvmDistr),
                blockVersionData: try c.decode(BlockVersionData.self, forKey: .blockVersionData),
                ftsSeed:          try c.decodeIfPresent(String.self, forKey: .ftsSeed),
                protocolConsts:   try c.decode(ProtocolConsts.self, forKey: .protocolConsts),
                startTime:        try c.decode(Int.self, forKey: .startTime),
                bootStakeholders: try c.decode([String: Int].self, forKey: .bootStakeholders),
                heavyDelegation:  try c.decode([String: HeavyDelegation].self, forKey: .heavyDelegation),
                nonAvvmBalances:  try c.decode([String: String].self, forKey: .nonAvvmBalances),
                vssCerts:         try c.decodeIfPresent([String: VSSCert].self, forKey: .vssCerts)
            )
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(avvmDistr, forKey: .avvmDistr)
            try c.encode(blockVersionData, forKey: .blockVersionData)
            try c.encodeIfPresent(ftsSeed, forKey: .ftsSeed)
            try c.encode(protocolConsts, forKey: .protocolConsts)
            try c.encode(startTime, forKey: .startTime)
            try c.encode(bootStakeholders, forKey: .bootStakeholders)
            try c.encode(heavyDelegation, forKey: .heavyDelegation)
            try c.encode(nonAvvmBalances, forKey: .nonAvvmBalances)
            try c.encodeIfPresent(vssCerts, forKey: .vssCerts)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        let dict = try Self.toStringDict(primitive, label: "ByronGenesis")
        avvmDistr         = try Self.readStringStringMap(dict["avvmDistr"] ?? .null, label: "avvmDistr")
        blockVersionData  = try BlockVersionData(from: dict["blockVersionData"] ?? .null)
        ftsSeed           = Self.optionalString(dict["ftsSeed"])
        protocolConsts    = try ProtocolConsts(from: dict["protocolConsts"] ?? .null)
        startTime         = Int(try Self.readUInt(dict["startTime"] ?? .null, label: "startTime"))
        bootStakeholders  = try Self.readStringIntMap(dict["bootStakeholders"] ?? .null, label: "bootStakeholders")
        heavyDelegation   = try Self.readHeavyDelegationMap(dict["heavyDelegation"] ?? .null)
        nonAvvmBalances   = try Self.readStringStringMap(dict["nonAvvmBalances"] ?? .null, label: "nonAvvmBalances")
        vssCerts          = try? Self.readVSSCertMap(dict["vssCerts"] ?? .null)
    }

    public func toPrimitive() throws -> Primitive {
        // Re-encode as a CBOR map with string keys (matching Byron's legacy encoding)
        var pairs: [(Primitive, Primitive)] = []
        pairs.append((.string("startTime"), .int(startTime)))
        if let seed = ftsSeed { pairs.append((.string("ftsSeed"), .string(seed))) }
        pairs.append((.string("protocolConsts"), try protocolConsts.toPrimitive()))
        pairs.append((.string("blockVersionData"), try blockVersionData.toPrimitive()))
        pairs.append((.string("bootStakeholders"), .dict(Dictionary(uniqueKeysWithValues:
            bootStakeholders.map { (.string($0.key), .int($0.value)) }))))
        pairs.append((.string("avvmDistr"), .dict(Dictionary(uniqueKeysWithValues:
            avvmDistr.map { (.string($0.key), .string($0.value)) }))))
        pairs.append((.string("nonAvvmBalances"), .dict(Dictionary(uniqueKeysWithValues:
            nonAvvmBalances.map { (.string($0.key), .string($0.value)) }))))
        pairs.append((.string("heavyDelegation"), .dict(Dictionary(uniqueKeysWithValues:
            try heavyDelegation.map { try (.string($0.key), $0.value.toPrimitive()) }))))
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }

    // MARK: Helpers

    private static func toStringDict(_ p: Primitive, label: String) throws -> [String: Primitive] {
        switch p {
        case .dict(let d):
            var result: [String: Primitive] = [:]
            for (k, v) in d {
                if case .string(let s) = k { result[s] = v }
            }
            return result
        case .orderedDict(let d):
            var result: [String: Primitive] = [:]
            for (k, v) in d {
                if case .string(let s) = k { result[s] = v }
            }
            return result
        default:
            throw CardanoCoreError.deserializeError("\(label): expected map (string keys)")
        }
    }

    private static func readUInt(_ p: Primitive, label: String) throws -> UInt64 {
        switch p {
        case .uint(let u): return UInt64(u)
        case .int(let i) where i >= 0: return UInt64(i)
        default:
            throw CardanoCoreError.deserializeError("ByronGenesis: expected uint for \(label)")
        }
    }

    private static func optionalString(_ p: Primitive?) -> String? {
        guard let p else { return nil }
        if case .string(let s) = p { return s }
        return nil
    }

    private static func readStringStringMap(_ p: Primitive, label: String) throws -> [String: String] {
        var result: [String: String] = [:]
        switch p {
        case .dict(let d):
            for (k, v) in d {
                if case .string(let ks) = k, case .string(let vs) = v { result[ks] = vs }
            }
        case .orderedDict(let d):
            for (k, v) in d {
                if case .string(let ks) = k, case .string(let vs) = v { result[ks] = vs }
            }
        case .null: break
        default:
            throw CardanoCoreError.deserializeError("ByronGenesis: expected string map for \(label)")
        }
        return result
    }

    private static func readStringIntMap(_ p: Primitive, label: String) throws -> [String: Int] {
        var result: [String: Int] = [:]
        switch p {
        case .dict(let d):
            for (k, v) in d {
                guard case .string(let ks) = k else { continue }
                switch v {
                case .int(let i): result[ks] = i
                case .uint(let u): result[ks] = Int(u)
                default: break
                }
            }
        case .orderedDict(let d):
            for (k, v) in d {
                guard case .string(let ks) = k else { continue }
                switch v {
                case .int(let i): result[ks] = i
                case .uint(let u): result[ks] = Int(u)
                default: break
                }
            }
        case .null: break
        default:
            throw CardanoCoreError.deserializeError("ByronGenesis: expected int map for \(label)")
        }
        return result
    }

    private static func readHeavyDelegationMap(_ p: Primitive) throws -> [String: HeavyDelegation] {
        var result: [String: HeavyDelegation] = [:]
        let dict: [(Primitive, Primitive)]
        switch p {
        case .dict(let d): dict = Array(d)
        case .orderedDict(let d): dict = d.map { ($0.key, $0.value) }
        case .null: return [:]
        default: return [:]
        }
        for (k, v) in dict {
            guard case .string(let ks) = k else { continue }
            result[ks] = try HeavyDelegation(from: v)
        }
        return result
    }

    private static func readVSSCertMap(_ p: Primitive) throws -> [String: VSSCert] {
        var result: [String: VSSCert] = [:]
        let dict: [(Primitive, Primitive)]
        switch p {
        case .dict(let d): dict = Array(d)
        case .orderedDict(let d): dict = d.map { ($0.key, $0.value) }
        default: return [:]
        }
        for (k, v) in dict {
            guard case .string(let ks) = k else { continue }
            result[ks] = try VSSCert(from: v)
        }
        return result
    }
}

// MARK: - Nested type CBOR extensions

extension BlockVersionData {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "BlockVersionData")
        heavyDelThd       = Self.str(dict["heavyDelThd"])
        maxBlockSize      = Self.str(dict["maxBlockSize"])
        maxHeaderSize     = Self.str(dict["maxHeaderSize"])
        maxProposalSize   = Self.str(dict["maxProposalSize"])
        maxTxSize         = Self.str(dict["maxTxSize"])
        mpcThd            = Self.str(dict["mpcThd"])
        scriptVersion     = Int(try ByronGenesis.readUIntPublic(dict["scriptVersion"] ?? .null, label: "scriptVersion"))
        slotDuration      = Self.str(dict["slotDuration"])
        softforkRule      = try SoftforkRule(from: dict["softforkRule"] ?? .null)
        txFeePolicy       = try TxFeePolicy(from: dict["txFeePolicy"] ?? .null)
        unlockStakeEpoch  = Self.str(dict["unlockStakeEpoch"])
        updateImplicit    = Self.str(dict["updateImplicit"])
        updateProposalThd = Self.str(dict["updateProposalThd"])
        updateVoteThd     = Self.str(dict["updateVoteThd"])
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("heavyDelThd"), .string(heavyDelThd)),
            (.string("maxBlockSize"), .string(maxBlockSize)),
            (.string("maxHeaderSize"), .string(maxHeaderSize)),
            (.string("maxProposalSize"), .string(maxProposalSize)),
            (.string("maxTxSize"), .string(maxTxSize)),
            (.string("mpcThd"), .string(mpcThd)),
            (.string("scriptVersion"), .int(scriptVersion)),
            (.string("slotDuration"), .string(slotDuration)),
            (.string("softforkRule"), try softforkRule.toPrimitive()),
            (.string("txFeePolicy"), try txFeePolicy.toPrimitive()),
            (.string("unlockStakeEpoch"), .string(unlockStakeEpoch)),
            (.string("updateImplicit"), .string(updateImplicit)),
            (.string("updateProposalThd"), .string(updateProposalThd)),
            (.string("updateVoteThd"), .string(updateVoteThd))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }

    private static func str(_ p: Primitive?) -> String {
        guard let p, case .string(let s) = p else { return "" }
        return s
    }
}

extension SoftforkRule {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "SoftforkRule")
        initThd      = ByronGenesis.strPublic(dict["initThd"])
        minThd       = ByronGenesis.strPublic(dict["minThd"])
        thdDecrement = ByronGenesis.strPublic(dict["thdDecrement"])
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("initThd"), .string(initThd)),
            (.string("minThd"), .string(minThd)),
            (.string("thdDecrement"), .string(thdDecrement))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension TxFeePolicy {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "TxFeePolicy")
        multiplier = ByronGenesis.strPublic(dict["multiplier"])
        summand    = ByronGenesis.strPublic(dict["summand"])
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("multiplier"), .string(multiplier)),
            (.string("summand"), .string(summand))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension ProtocolConsts {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "ProtocolConsts")
        k             = Int(try ByronGenesis.readUIntPublic(dict["k"] ?? .null, label: "k"))
        protocolMagic = Int(try ByronGenesis.readUIntPublic(dict["protocolMagic"] ?? .null, label: "protocolMagic"))
        vssMaxTTL     = dict["vssMaxTTL"].flatMap { if case .uint(let u) = $0 { return Int(u) } else if case .int(let i) = $0 { return i }; return nil }
        vssMinTTL     = dict["vssMinTTL"].flatMap { if case .uint(let u) = $0 { return Int(u) } else if case .int(let i) = $0 { return i }; return nil }
    }

    public func toPrimitive() throws -> Primitive {
        var pairs: [(Primitive, Primitive)] = [
            (.string("k"), .int(k)),
            (.string("protocolMagic"), .int(protocolMagic))
        ]
        if let max = vssMaxTTL { pairs.append((.string("vssMaxTTL"), .int(max))) }
        if let min = vssMinTTL { pairs.append((.string("vssMinTTL"), .int(min))) }
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension HeavyDelegation {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "HeavyDelegation")
        cert       = ByronGenesis.strPublic(dict["cert"])
        delegatePk = ByronGenesis.strPublic(dict["delegatePk"])
        issuerPk   = ByronGenesis.strPublic(dict["issuerPk"])
        omega      = Int(try ByronGenesis.readUIntPublic(dict["omega"] ?? .null, label: "omega"))
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("cert"), .string(cert)),
            (.string("delegatePk"), .string(delegatePk)),
            (.string("issuerPk"), .string(issuerPk)),
            (.string("omega"), .int(omega))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension VSSCert {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "VSSCert")
        expiryEpoch = Int(try ByronGenesis.readUIntPublic(dict["expiryEpoch"] ?? .null, label: "expiryEpoch"))
        signature   = ByronGenesis.strPublic(dict["signature"])
        signingKey  = ByronGenesis.strPublic(dict["signingKey"])
        vssKey      = ByronGenesis.strPublic(dict["vssKey"])
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("expiryEpoch"), .int(expiryEpoch)),
            (.string("signature"), .string(signature)),
            (.string("signingKey"), .string(signingKey)),
            (.string("vssKey"), .string(vssKey))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

// Internal shared helpers exposed to nested types in this file
extension ByronGenesis {
    static func toStringDictPublic(_ p: Primitive, label: String) throws -> [String: Primitive] {
        switch p {
        case .dict(let d):
            var result: [String: Primitive] = [:]
            for (k, v) in d { if case .string(let s) = k { result[s] = v } }
            return result
        case .orderedDict(let d):
            var result: [String: Primitive] = [:]
            for (k, v) in d { if case .string(let s) = k { result[s] = v } }
            return result
        default:
            throw CardanoCoreError.deserializeError("\(label): expected string-keyed map")
        }
    }

    static func readUIntPublic(_ p: Primitive, label: String) throws -> UInt64 {
        switch p {
        case .uint(let u): return UInt64(u)
        case .int(let i) where i >= 0: return UInt64(i)
        default:
            throw CardanoCoreError.deserializeError("ByronGenesis: expected uint for \(label)")
        }
    }

    static func strPublic(_ p: Primitive?) -> String {
        guard let p, case .string(let s) = p else { return "" }
        return s
    }
}

// MARK: - Sendable
extension ByronGenesis: Sendable {}
extension BlockVersionData: Sendable {}
extension SoftforkRule: Sendable {}
extension TxFeePolicy: Sendable {}
extension ProtocolConsts: Sendable {}
extension HeavyDelegation: Sendable {}
extension VSSCert: Sendable {}
