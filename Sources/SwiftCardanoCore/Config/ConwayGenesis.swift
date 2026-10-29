import Foundation
import OrderedCollections
@preconcurrency import BigInt

/// The ledger's `ConwayGenesis` (cardano-ledger, `Cardano.Ledger.Conway.Genesis`):
/// the `UpgradeConwayPParams`, the constitution, the committee, the initial
/// delegations and DReps, and the optional extra configuration. Each integer
/// field has the width of its ledger type, and each rational is held exactly.
public struct ConwayGenesis: JSONLoadable {
    public let poolVotingThresholds: ConwayGenesisPoolVotingThresholds
    public let dRepVotingThresholds: ConwayGenesisDRepVotingThresholds
    /// `Word16`.
    public let committeeMinSize: UInt16
    /// `EpochInterval`, a `Word32`.
    public let committeeMaxTermLength: EpochInterval
    /// `EpochInterval`, a `Word32`.
    public let govActionLifetime: EpochInterval
    /// `Coin`.
    public let govActionDeposit: Coin
    /// `Coin`.
    public let dRepDeposit: Coin
    /// `EpochInterval`, a `Word32`.
    public let dRepActivity: EpochInterval
    /// A `NonNegativeInterval`, which need not be a whole number.
    public let minFeeRefScriptCostPerByte: NonNegativeInterval
    /// The PlutusV3 `CostModel`: its `Int64` parameters, in order.
    public let plutusV3CostModel: [Int64]
    public let constitution: ConwayGenesisConstitution
    public let committee: Committee
    /// `ListMap (Credential Staking) Delegatee`, in its order.
    public let delegs: [ConwayGenesisDelegation]
    /// `ListMap (Credential DRepRole) DRepState`, in its order.
    public let initialDReps: [ConwayGenesisInitialDRep]
    /// `StrictMaybe ConwayExtraConfig`.
    public let extraConfig: ConwayGenesisExtraConfig?

    public init(
        poolVotingThresholds: ConwayGenesisPoolVotingThresholds,
        dRepVotingThresholds: ConwayGenesisDRepVotingThresholds,
        committeeMinSize: UInt16,
        committeeMaxTermLength: EpochInterval,
        govActionLifetime: EpochInterval,
        govActionDeposit: Coin,
        dRepDeposit: Coin,
        dRepActivity: EpochInterval,
        minFeeRefScriptCostPerByte: NonNegativeInterval,
        plutusV3CostModel: [Int64],
        constitution: ConwayGenesisConstitution,
        committee: Committee,
        delegs: [ConwayGenesisDelegation] = [],
        initialDReps: [ConwayGenesisInitialDRep] = [],
        extraConfig: ConwayGenesisExtraConfig? = nil
    ) {
        self.poolVotingThresholds = poolVotingThresholds
        self.dRepVotingThresholds = dRepVotingThresholds
        self.committeeMinSize = committeeMinSize
        self.committeeMaxTermLength = committeeMaxTermLength
        self.govActionLifetime = govActionLifetime
        self.govActionDeposit = govActionDeposit
        self.dRepDeposit = dRepDeposit
        self.dRepActivity = dRepActivity
        self.minFeeRefScriptCostPerByte = minFeeRefScriptCostPerByte
        self.plutusV3CostModel = plutusV3CostModel
        self.constitution = constitution
        self.committee = committee
        self.delegs = delegs
        self.initialDReps = initialDReps
        self.extraConfig = extraConfig
    }
}

// MARK: - Voting thresholds

/// The ledger's `PoolVotingThresholds`: five `UnitInterval`s.
public struct ConwayGenesisPoolVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let committeeNormal: UnitInterval
    public let committeeNoConfidence: UnitInterval
    public let hardForkInitiation: UnitInterval
    public let motionNoConfidence: UnitInterval
    public let ppSecurityGroup: UnitInterval

    public init(committeeNormal: UnitInterval, committeeNoConfidence: UnitInterval,
                hardForkInitiation: UnitInterval, motionNoConfidence: UnitInterval,
                ppSecurityGroup: UnitInterval) {
        self.committeeNormal = committeeNormal
        self.committeeNoConfidence = committeeNoConfidence
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppSecurityGroup = ppSecurityGroup
    }

    private enum CodingKeys: String, CodingKey {
        case committeeNormal, committeeNoConfidence, hardForkInitiation, motionNoConfidence, ppSecurityGroup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        committeeNormal = try c.decodeUnitInterval(forKey: .committeeNormal)
        committeeNoConfidence = try c.decodeUnitInterval(forKey: .committeeNoConfidence)
        hardForkInitiation = try c.decodeUnitInterval(forKey: .hardForkInitiation)
        motionNoConfidence = try c.decodeUnitInterval(forKey: .motionNoConfidence)
        ppSecurityGroup = try c.decodeUnitInterval(forKey: .ppSecurityGroup)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLedgerRational(committeeNormal, forKey: .committeeNormal)
        try c.encodeLedgerRational(committeeNoConfidence, forKey: .committeeNoConfidence)
        try c.encodeLedgerRational(hardForkInitiation, forKey: .hardForkInitiation)
        try c.encodeLedgerRational(motionNoConfidence, forKey: .motionNoConfidence)
        try c.encodeLedgerRational(ppSecurityGroup, forKey: .ppSecurityGroup)
    }

    // CBOR order (cardano-ledger `EncCBOR PoolVotingThresholds`):
    //   [motionNoConfidence, committeeNormal, committeeNoConfidence,
    //    hardForkInitiation, ppSecurityGroup]
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 5, "PoolVotingThresholds")
        func read(_ i: Int, _ label: String) throws -> UnitInterval {
            try UnitInterval.ledgerCBOR(f[i], "PoolVotingThresholds \(label)")
        }
        motionNoConfidence    = try read(0, "motionNoConfidence")
        committeeNormal       = try read(1, "committeeNormal")
        committeeNoConfidence = try read(2, "committeeNoConfidence")
        hardForkInitiation    = try read(3, "hardForkInitiation")
        ppSecurityGroup       = try read(4, "ppSecurityGroup")
    }

    public func toPrimitive() throws -> Primitive {
        .list([motionNoConfidence, committeeNormal, committeeNoConfidence, hardForkInitiation, ppSecurityGroup]
            .map { $0.ledgerPrimitive() })
    }
}

/// The ledger's `DRepVotingThresholds`: ten `UnitInterval`s.
public struct ConwayGenesisDRepVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let motionNoConfidence: UnitInterval
    public let committeeNormal: UnitInterval
    public let committeeNoConfidence: UnitInterval
    public let updateToConstitution: UnitInterval
    public let hardForkInitiation: UnitInterval
    public let ppNetworkGroup: UnitInterval
    public let ppEconomicGroup: UnitInterval
    public let ppTechnicalGroup: UnitInterval
    public let ppGovGroup: UnitInterval
    public let treasuryWithdrawal: UnitInterval

    public init(motionNoConfidence: UnitInterval, committeeNormal: UnitInterval,
                committeeNoConfidence: UnitInterval, updateToConstitution: UnitInterval,
                hardForkInitiation: UnitInterval, ppNetworkGroup: UnitInterval,
                ppEconomicGroup: UnitInterval, ppTechnicalGroup: UnitInterval,
                ppGovGroup: UnitInterval, treasuryWithdrawal: UnitInterval) {
        self.motionNoConfidence = motionNoConfidence
        self.committeeNormal = committeeNormal
        self.committeeNoConfidence = committeeNoConfidence
        self.updateToConstitution = updateToConstitution
        self.hardForkInitiation = hardForkInitiation
        self.ppNetworkGroup = ppNetworkGroup
        self.ppEconomicGroup = ppEconomicGroup
        self.ppTechnicalGroup = ppTechnicalGroup
        self.ppGovGroup = ppGovGroup
        self.treasuryWithdrawal = treasuryWithdrawal
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case motionNoConfidence, committeeNormal, committeeNoConfidence, updateToConstitution
        case hardForkInitiation, ppNetworkGroup, ppEconomicGroup, ppTechnicalGroup, ppGovGroup
        case treasuryWithdrawal
    }

    /// The thresholds in the ledger's CBOR order, which is the order above.
    private var ordered: [UnitInterval] {
        [motionNoConfidence, committeeNormal, committeeNoConfidence, updateToConstitution,
         hardForkInitiation, ppNetworkGroup, ppEconomicGroup, ppTechnicalGroup, ppGovGroup,
         treasuryWithdrawal]
    }

    private init(ordered v: [UnitInterval]) {
        self.init(motionNoConfidence: v[0], committeeNormal: v[1], committeeNoConfidence: v[2],
                  updateToConstitution: v[3], hardForkInitiation: v[4], ppNetworkGroup: v[5],
                  ppEconomicGroup: v[6], ppTechnicalGroup: v[7], ppGovGroup: v[8],
                  treasuryWithdrawal: v[9])
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(ordered: try CodingKeys.allCases.map { try c.decodeUnitInterval(forKey: $0) })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in zip(CodingKeys.allCases, ordered) {
            try c.encodeLedgerRational(value, forKey: key)
        }
    }

    // CBOR (cardano-ledger `EncCBOR DRepVotingThresholds`): the order above.
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 10, "DRepVotingThresholds")
        self.init(ordered: try zip(f, CodingKeys.allCases).map {
            try UnitInterval.ledgerCBOR($0.0, "DRepVotingThresholds \($0.1.stringValue)")
        })
    }

    public func toPrimitive() throws -> Primitive {
        .list(ordered.map { $0.ledgerPrimitive() })
    }
}

// MARK: - Constitution

/// The ledger's `Constitution`: an anchor and an optional guardrails script
/// hash (`StrictMaybe ScriptHash`).
public struct ConwayGenesisConstitution: Codable, Equatable, Hashable, Sendable {
    public let anchor: ConwayGenesisAnchor
    /// The guardrails script hash as hex (28 bytes), when there is one.
    public let script: String?

    public init(anchor: ConwayGenesisAnchor, script: String?) {
        self.anchor = anchor
        self.script = script
    }

    private enum CodingKeys: String, CodingKey { case anchor, script }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        anchor = try c.decode(ConwayGenesisAnchor.self, forKey: .anchor)
        script = try c.decodeIfPresent(String.self, forKey: .script).map {
            try conwayHash(hex: $0, size: 28, "Constitution script").toHex
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(anchor, forKey: .anchor)
        try c.encodeIfPresent(script, forKey: .script)
    }

    // CBOR (cardano-ledger `EncCBOR Constitution`): [anchor, script_hash / null].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 2, "Constitution")
        anchor = try ConwayGenesisAnchor(from: f[0])
        if case .null = f[1] {
            script = nil
        } else {
            script = try conwayBytes(f[1], size: 28, "Constitution script").toHex
        }
    }

    public func toPrimitive() throws -> Primitive {
        let scriptPrim: Primitive = try script.map {
            .bytes(try conwayHash(hex: $0, size: 28, "Constitution script"))
        } ?? .null
        return .list([try anchor.toPrimitive(), scriptPrim])
    }
}

/// The ledger's `Anchor`: a URL of at most 128 bytes and a 32-byte hash.
public struct ConwayGenesisAnchor: Codable, Equatable, Hashable, Sendable {
    /// The 32-byte data hash, as hex.
    public let dataHash: String
    public let url: String

    public init(dataHash: String, url: String) {
        self.dataHash = dataHash
        self.url = url
    }

    private enum CodingKeys: String, CodingKey { case dataHash, url }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try conwayURL(try c.decode(String.self, forKey: .url))
        dataHash = try conwayHash(hex: try c.decode(String.self, forKey: .dataHash), size: 32,
                                  "Anchor dataHash").toHex
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(url, forKey: .url)
        try c.encode(dataHash, forKey: .dataHash)
    }

    // CBOR (cardano-ledger `EncCBOR Anchor`): [url, bytes .size 32].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 2, "Anchor")
        guard case .string(let u) = f[0] else {
            throw CardanoCoreError.deserializeError("Anchor: the url must be text, got \(f[0])")
        }
        url = try conwayURL(u)
        dataHash = try conwayBytes(f[1], size: 32, "Anchor dataHash").toHex
    }

    public func toPrimitive() throws -> Primitive {
        .list([.string(try conwayURL(url)), .bytes(try conwayHash(hex: dataHash, size: 32, "Anchor dataHash"))])
    }
}

// MARK: - Credentials, DReps and delegatees

/// A ledger `Credential`: a key hash or a script hash, 28 bytes each.
///
/// As a JSON map key it is written `keyHash-<hex>` or `scriptHash-<hex>`.
/// It orders as the ledger's `Credential` does: script hashes first, then by
/// hash bytes.
public struct GenesisCredential: Hashable, Comparable, Sendable {
    public enum Kind: Hashable, Sendable { case keyHash, scriptHash }

    public let kind: Kind
    /// 28 bytes.
    public let hash: Data

    public init(kind: Kind, hash: Data) throws {
        guard hash.count == 28 else {
            throw CardanoCoreError.valueError("Credential: a hash has 28 bytes, got \(hash.count)")
        }
        self.kind = kind
        self.hash = hash
    }

    /// Parses `keyHash-<hex>` or `scriptHash-<hex>`, as the ledger's
    /// `parseCredential` does.
    public init(text: String) throws {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid credential: \(text)")
        }
        let kind: Kind
        switch parts[0] {
        case "keyHash": kind = .keyHash
        case "scriptHash": kind = .scriptHash
        default: throw CardanoCoreError.deserializeError("Invalid credential: \(text)")
        }
        try self.init(kind: kind, hash: try conwayHash(hex: String(parts[1]), size: 28, "Credential"))
    }

    /// `keyHash-<hex>` or `scriptHash-<hex>`.
    public var text: String { (kind == .keyHash ? "keyHash-" : "scriptHash-") + hash.toHex }

    // CBOR (cardano-ledger `EncCBOR Credential`): [0, key hash] / [1, script hash].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 2, "Credential")
        let tag = try f[0].integer("Credential tag", as: UInt8.self)
        let kind: Kind
        switch tag {
        case 0: kind = .keyHash
        case 1: kind = .scriptHash
        default: throw CardanoCoreError.deserializeError("Credential: unknown tag \(tag)")
        }
        try self.init(kind: kind, hash: try conwayBytes(f[1], size: 28, "Credential hash"))
    }

    public func toPrimitive() -> Primitive {
        .list([.uint(kind == .keyHash ? 0 : 1), .bytes(hash)])
    }

    public static func < (lhs: GenesisCredential, rhs: GenesisCredential) -> Bool {
        if lhs.kind != rhs.kind { return lhs.kind == .scriptHash }
        return lhs.hash.lexicographicallyPrecedes(rhs.hash)
    }
}

/// The ledger's `DRep`.
public enum GenesisDRep: Hashable, Sendable {
    /// A 28-byte key hash.
    case keyHash(Data)
    /// A 28-byte script hash.
    case scriptHash(Data)
    case alwaysAbstain
    case alwaysNoConfidence

    /// `drep-keyHash-<hex>`, `drep-scriptHash-<hex>`, `drep-alwaysAbstain` or
    /// `drep-alwaysNoConfidence`, as the ledger writes it.
    public var text: String {
        switch self {
        case .keyHash(let h): return "drep-keyHash-" + h.toHex
        case .scriptHash(let h): return "drep-scriptHash-" + h.toHex
        case .alwaysAbstain: return "drep-alwaysAbstain"
        case .alwaysNoConfidence: return "drep-alwaysNoConfidence"
        }
    }

    public init(text: String) throws {
        switch text {
        case "drep-alwaysAbstain": self = .alwaysAbstain
        case "drep-alwaysNoConfidence": self = .alwaysNoConfidence
        default:
            guard text.hasPrefix("drep-") else {
                throw CardanoCoreError.deserializeError("Invalid DRep: \(text)")
            }
            let credential = try GenesisCredential(text: String(text.dropFirst(5)))
            self = credential.kind == .keyHash ? .keyHash(credential.hash) : .scriptHash(credential.hash)
        }
    }

    // CBOR (cardano-ledger `EncCBOR DRep`): [0, h] / [1, h] / [2] / [3].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, "DRep")
        guard let first = f.first else { throw CardanoCoreError.deserializeError("DRep: empty list") }
        switch (try first.integer("DRep tag", as: UInt8.self), f.count) {
        case (0, 2): self = .keyHash(try conwayBytes(f[1], size: 28, "DRep key hash"))
        case (1, 2): self = .scriptHash(try conwayBytes(f[1], size: 28, "DRep script hash"))
        case (2, 1): self = .alwaysAbstain
        case (3, 1): self = .alwaysNoConfidence
        case let (tag, count):
            throw CardanoCoreError.deserializeError("DRep: tag \(tag) with \(count) elements")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .keyHash(let h): return .list([.uint(0), .bytes(try conwaySized(h, 28, "DRep key hash"))])
        case .scriptHash(let h): return .list([.uint(1), .bytes(try conwaySized(h, 28, "DRep script hash"))])
        case .alwaysAbstain: return .list([.uint(2)])
        case .alwaysNoConfidence: return .list([.uint(3)])
        }
    }
}

/// The ledger's `Delegatee`: a stake pool, a DRep, or both.
public enum GenesisDelegatee: Hashable, Sendable {
    /// A stake pool's 28-byte key hash.
    case stake(pool: Data)
    case vote(GenesisDRep)
    case stakeVote(pool: Data, dRep: GenesisDRep)

    // CBOR (cardano-ledger `EncCBOR Delegatee`): [0, pool] / [1, drep] / [2, pool, drep].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, "Delegatee")
        guard let first = f.first else { throw CardanoCoreError.deserializeError("Delegatee: empty list") }
        switch (try first.integer("Delegatee tag", as: UInt8.self), f.count) {
        case (0, 2):
            self = .stake(pool: try conwayBytes(f[1], size: 28, "Delegatee pool"))
        case (1, 2):
            self = .vote(try GenesisDRep(from: f[1]))
        case (2, 3):
            self = .stakeVote(pool: try conwayBytes(f[1], size: 28, "Delegatee pool"),
                              dRep: try GenesisDRep(from: f[2]))
        case let (tag, count):
            throw CardanoCoreError.deserializeError("Delegatee: tag \(tag) with \(count) elements")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .stake(let pool):
            return .list([.uint(0), .bytes(try conwaySized(pool, 28, "Delegatee pool"))])
        case .vote(let dRep):
            return .list([.uint(1), try dRep.toPrimitive()])
        case .stakeVote(let pool, let dRep):
            return .list([.uint(2), .bytes(try conwaySized(pool, 28, "Delegatee pool")), try dRep.toPrimitive()])
        }
    }
}

extension GenesisDelegatee: Codable {
    private enum CodingKeys: String, CodingKey { case kind, poolId, dRep }

    // JSON (cardano-ledger `FromJSON Delegatee`): `poolId`, `dRep` or both.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let pool = try c.decodeIfPresent(String.self, forKey: .poolId)
            .map { try conwayHash(hex: $0, size: 28, "Delegatee poolId") }
        let dRep = try c.decodeIfPresent(String.self, forKey: .dRep).map { try GenesisDRep(text: $0) }
        switch (pool, dRep) {
        case (let pool?, nil): self = .stake(pool: pool)
        case (nil, let dRep?): self = .vote(dRep)
        case (let pool?, let dRep?): self = .stakeVote(pool: pool, dRep: dRep)
        case (nil, nil):
            throw CardanoCoreError.deserializeError("Delegatee: object does not contain a dRep or a poolId field")
        }
    }

    // JSON (cardano-ledger `ToJSON Delegatee`): a `kind` and its fields.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stake(let pool):
            try c.encode("DelegStake", forKey: .kind)
            try c.encode(pool.toHex, forKey: .poolId)
        case .vote(let dRep):
            try c.encode("DelegVote", forKey: .kind)
            try c.encode(dRep.text, forKey: .dRep)
        case .stakeVote(let pool, let dRep):
            try c.encode("DelegStakeVote", forKey: .kind)
            try c.encode(pool.toHex, forKey: .poolId)
            try c.encode(dRep.text, forKey: .dRep)
        }
    }
}

/// The ledger's `DRepState`.
public struct GenesisDRepState: Codable, Hashable, Sendable {
    /// `EpochNo`, a `Word64`.
    public let expiry: EpochNumber
    public let anchor: ConwayGenesisAnchor?
    /// `CompactForm Coin`, a `Word64`.
    public let deposit: Coin
    /// `Set (Credential Staking)`, in the set's order. The ledger's JSON
    /// neither reads nor writes it.
    public let delegs: [GenesisCredential]

    public init(expiry: EpochNumber, anchor: ConwayGenesisAnchor?, deposit: Coin, delegs: [GenesisCredential] = []) {
        self.expiry = expiry
        self.anchor = anchor
        self.deposit = deposit
        self.delegs = Array(Set(delegs)).sorted()
    }

    private enum CodingKeys: String, CodingKey { case expiry, anchor, deposit }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(expiry: try c.decode(EpochNumber.self, forKey: .expiry),
                  anchor: try c.decodeIfPresent(ConwayGenesisAnchor.self, forKey: .anchor),
                  deposit: try c.decode(Coin.self, forKey: .deposit))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(expiry, forKey: .expiry)
        try c.encode(deposit, forKey: .deposit)
        try c.encodeIfPresent(anchor, forKey: .anchor)
    }

    // CBOR (cardano-ledger `EncCBOR DRepState`):
    //   [expiry, [] / [anchor], deposit, #6.258([* credential])]
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 4, "DRepState")
        let expiry = try f[0].integer("DRepState expiry", as: EpochNumber.self)
        let maybe = try conwayList(f[1], "DRepState anchor")
        guard maybe.count <= 1 else {
            throw CardanoCoreError.deserializeError("DRepState anchor: a StrictMaybe has at most one element")
        }
        let anchor = try maybe.first.map { try ConwayGenesisAnchor(from: $0) }
        let deposit = try f[2].integer("DRepState deposit", as: Coin.self)
        let delegs = try conwaySet(f[3], "DRepState delegs").map { try GenesisCredential(from: $0) }
        guard Set(delegs).count == delegs.count else {
            throw CardanoCoreError.deserializeError("DRepState delegs: a set holds each credential once")
        }
        self.init(expiry: expiry, anchor: anchor, deposit: deposit, delegs: delegs)
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            .uint(expiry),
            .list(try anchor.map { [try $0.toPrimitive()] } ?? []),
            .uint(deposit),
            conwaySetPrimitive(delegs.sorted().map { $0.toPrimitive() }),
        ])
    }
}

/// One entry of the genesis `delegs` list map.
public struct ConwayGenesisDelegation: Hashable, Sendable {
    public let credential: GenesisCredential
    public let delegatee: GenesisDelegatee

    public init(credential: GenesisCredential, delegatee: GenesisDelegatee) {
        self.credential = credential
        self.delegatee = delegatee
    }
}

/// One entry of the genesis `initialDReps` list map.
public struct ConwayGenesisInitialDRep: Hashable, Sendable {
    public let credential: GenesisCredential
    public let state: GenesisDRepState

    public init(credential: GenesisCredential, state: GenesisDRepState) {
        self.credential = credential
        self.state = state
    }
}

// MARK: - Extra configuration

/// The ledger's `InjectionData`: nothing, a file with its Blake2b-256 hash,
/// or embedded entries.
public enum GenesisInjectionData<Entry: Hashable & Sendable>: Hashable, Sendable {
    case noInjection
    /// The file's path segments and its 32-byte hash.
    case fromFile(path: [String], hash: Data)
    case embedded([Entry])
}

/// The ledger's `ConwayExtraConfig`.
public struct ConwayGenesisExtraConfig: Hashable, Sendable {
    public let delegs: GenesisInjectionData<ConwayGenesisDelegation>
    public let initialDReps: GenesisInjectionData<ConwayGenesisInitialDRep>

    public init(delegs: GenesisInjectionData<ConwayGenesisDelegation> = .noInjection,
                initialDReps: GenesisInjectionData<ConwayGenesisInitialDRep> = .noInjection) {
        self.delegs = delegs
        self.initialDReps = initialDReps
    }
}

// MARK: - List maps (ListMap) in CBOR and JSON

/// An entry of a `ListMap` keyed by a credential.
fileprivate protocol CredentialListMapEntry: Hashable, Sendable {
    associatedtype Value: Codable
    static var label: String { get }
    var key: GenesisCredential { get }
    var jsonValue: Value { get }
    init(key: GenesisCredential, jsonValue: Value)
    init(key: GenesisCredential, cbor: Primitive) throws
    func cborValue() throws -> Primitive
}

extension ConwayGenesisDelegation: CredentialListMapEntry {
    fileprivate static var label: String { "delegs" }
    fileprivate var key: GenesisCredential { credential }
    fileprivate var jsonValue: GenesisDelegatee { delegatee }
    fileprivate init(key: GenesisCredential, jsonValue: GenesisDelegatee) {
        self.init(credential: key, delegatee: jsonValue)
    }
    fileprivate init(key: GenesisCredential, cbor: Primitive) throws {
        self.init(credential: key, delegatee: try GenesisDelegatee(from: cbor))
    }
    fileprivate func cborValue() throws -> Primitive { try delegatee.toPrimitive() }
}

extension ConwayGenesisInitialDRep: CredentialListMapEntry {
    fileprivate static var label: String { "initialDReps" }
    fileprivate var key: GenesisCredential { credential }
    fileprivate var jsonValue: GenesisDRepState { state }
    fileprivate init(key: GenesisCredential, jsonValue: GenesisDRepState) {
        self.init(credential: key, state: jsonValue)
    }
    fileprivate init(key: GenesisCredential, cbor: Primitive) throws {
        self.init(credential: key, state: try GenesisDRepState(from: cbor))
    }
    fileprivate func cborValue() throws -> Primitive { try state.toPrimitive() }
}

fileprivate struct ConwayJSONKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// A `ListMap` read from CBOR: a definite-length map, in its order
/// (cardano-data `DecCBOR ListMap` reads `decodeMapLen`).
fileprivate func readListMap<E: CredentialListMapEntry>(_ p: Primitive) throws -> [E] {
    guard case .orderedDict(let d) = p else {
        throw CardanoCoreError.deserializeError("\(E.label): expected a definite-length map, got \(p)")
    }
    return try d.elements.map { try E(key: GenesisCredential(from: $0.key), cbor: $0.value) }
}

/// A `ListMap` as the ledger writes it: a definite-length map in list order.
fileprivate func listMapPrimitive<E: CredentialListMapEntry>(_ entries: [E]) throws -> Primitive {
    var d = OrderedDictionary<Primitive, Primitive>()
    for e in entries { d[e.key.toPrimitive()] = try e.cborValue() }
    guard d.count == entries.count else {
        throw CardanoCoreError.valueError("\(E.label): a credential appears more than once")
    }
    return .orderedDict(d)
}

/// A `ListMap` read from a JSON object. aeson reads an object into a map
/// ordered by key, so the entries come in the order of their key text.
fileprivate func decodeListMap<E: CredentialListMapEntry>(_ decoder: Decoder) throws -> [E] {
    let c = try decoder.container(keyedBy: ConwayJSONKey.self)
    let keys = c.allKeys.sorted {
        Array($0.stringValue.utf8).lexicographicallyPrecedes(Array($1.stringValue.utf8))
    }
    return try keys.map { key in
        E(key: try GenesisCredential(text: key.stringValue), jsonValue: try c.decode(E.Value.self, forKey: key))
    }
}

/// A list map's JSON object on its own, for keyed containers.
fileprivate struct JSONListMap<E: CredentialListMapEntry>: Codable {
    let entries: [E]
    init(_ entries: [E]) { self.entries = entries }
    init(from decoder: Decoder) throws { entries = try decodeListMap(decoder) }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ConwayJSONKey.self)
        for e in entries { try c.encode(e.jsonValue, forKey: ConwayJSONKey(stringValue: e.key.text)) }
    }
}

// MARK: InjectionData

extension GenesisInjectionData where Entry: CredentialListMapEntry {
    // CBOR (cardano-ledger `EncCBOR InjectionData`):
    //   [0] / [1, [* text], bytes .size 32] / [2, list map]
    fileprivate init(cbor primitive: Primitive) throws {
        let f = try conwayList(primitive, "InjectionData")
        guard let first = f.first else { throw CardanoCoreError.deserializeError("InjectionData: empty list") }
        switch (try first.integer("InjectionData tag", as: UInt64.self), f.count) {
        case (0, 1):
            self = .noInjection
        case (1, 3):
            let path = try conwayList(f[1], "InjectionData path").map { item -> String in
                guard case .string(let s) = item else {
                    throw CardanoCoreError.deserializeError("InjectionData path: segments are text")
                }
                return s
            }
            self = .fromFile(path: path, hash: try conwayBytes(f[2], size: 32, "InjectionData hash"))
        case (2, 2):
            self = .embedded(try readListMap(f[1]))
        case let (tag, count):
            throw CardanoCoreError.deserializeError("InjectionData: tag \(tag) with \(count) elements")
        }
    }

    fileprivate func cborPrimitive() throws -> Primitive {
        switch self {
        case .noInjection:
            return .list([.uint(0)])
        case .fromFile(let path, let hash):
            return .list([.uint(1), .list(path.map { .string($0) }),
                          .bytes(try conwaySized(hash, 32, "InjectionData hash"))])
        case .embedded(let entries):
            return .list([.uint(2), try listMapPrimitive(entries)])
        }
    }
}

/// `InjectionData` in JSON: `{}`, `{"file": [..], "hash": hex}` or `{"data": {..}}`.
fileprivate struct JSONInjection<E: CredentialListMapEntry>: Codable {
    let value: GenesisInjectionData<E>
    init(_ value: GenesisInjectionData<E>) { self.value = value }

    private enum CodingKeys: String, CodingKey { case file, hash, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let file = try c.decodeIfPresent([String].self, forKey: .file)
        let data = try c.decodeIfPresent(JSONListMap<E>.self, forKey: .data)
        switch (file, data) {
        case (let file?, nil):
            let hash = try conwayHash(hex: try c.decode(String.self, forKey: .hash), size: 32, "InjectionData hash")
            value = .fromFile(path: file, hash: hash)
        case (nil, let data?):
            value = .embedded(data.entries)
        case (nil, nil):
            value = .noInjection
        case (.some, .some):
            throw CardanoCoreError.deserializeError(
                "InjectionData: cannot specify both \"file\" and \"data\" fields")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch value {
        case .noInjection:
            break
        case .fromFile(let path, let hash):
            try c.encode(path, forKey: .file)
            try c.encode(hash.toHex, forKey: .hash)
        case .embedded(let entries):
            try c.encode(JSONListMap(entries), forKey: .data)
        }
    }
}

extension ConwayGenesisExtraConfig: Codable {
    private enum CodingKeys: String, CodingKey { case delegs, initialDReps }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        delegs = try c.decodeIfPresent(JSONInjection<ConwayGenesisDelegation>.self, forKey: .delegs)?.value
            ?? .noInjection
        initialDReps = try c.decodeIfPresent(JSONInjection<ConwayGenesisInitialDRep>.self,
                                             forKey: .initialDReps)?.value ?? .noInjection
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(JSONInjection(delegs), forKey: .delegs)
        try c.encode(JSONInjection(initialDReps), forKey: .initialDReps)
    }

    // CBOR (cardano-ledger `EncCBOR ConwayExtraConfig`): [delegs, initialDReps].
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 2, "ConwayExtraConfig")
        delegs = try GenesisInjectionData(cbor: f[0])
        initialDReps = try GenesisInjectionData(cbor: f[1])
    }

    public func toPrimitive() throws -> Primitive {
        .list([try delegs.cborPrimitive(), try initialDReps.cborPrimitive()])
    }
}

// MARK: - ConwayGenesis JSON and CBOR

extension ConwayGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case poolVotingThresholds, dRepVotingThresholds, committeeMinSize
        case committeeMaxTermLength, govActionLifetime, govActionDeposit
        case dRepDeposit, dRepActivity, minFeeRefScriptCostPerByte
        case plutusV3CostModel, constitution, committee
        case delegs, initialDReps, extraConfig
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            // cardano-ledger `FromJSON ConwayGenesis`.
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                poolVotingThresholds: try c.decode(ConwayGenesisPoolVotingThresholds.self,
                                                   forKey: .poolVotingThresholds),
                dRepVotingThresholds: try c.decode(ConwayGenesisDRepVotingThresholds.self,
                                                   forKey: .dRepVotingThresholds),
                committeeMinSize: try c.decode(UInt16.self, forKey: .committeeMinSize),
                committeeMaxTermLength: try c.decode(EpochInterval.self, forKey: .committeeMaxTermLength),
                govActionLifetime: try c.decode(EpochInterval.self, forKey: .govActionLifetime),
                govActionDeposit: try c.decode(Coin.self, forKey: .govActionDeposit),
                dRepDeposit: try c.decode(Coin.self, forKey: .dRepDeposit),
                dRepActivity: try c.decode(EpochInterval.self, forKey: .dRepActivity),
                minFeeRefScriptCostPerByte: try c.decodeNonNegativeInterval(forKey: .minFeeRefScriptCostPerByte),
                plutusV3CostModel: try c.decode([Int64].self, forKey: .plutusV3CostModel),
                constitution: try c.decode(ConwayGenesisConstitution.self, forKey: .constitution),
                committee: try c.decode(Committee.self, forKey: .committee),
                delegs: try c.decodeIfPresent(JSONListMap<ConwayGenesisDelegation>.self,
                                              forKey: .delegs)?.entries ?? [],
                initialDReps: try c.decodeIfPresent(JSONListMap<ConwayGenesisInitialDRep>.self,
                                                    forKey: .initialDReps)?.entries ?? [],
                extraConfig: try c.decodeIfPresent(ConwayGenesisExtraConfig.self, forKey: .extraConfig)
            )
        } else {
            // Definite-length maps decode in order, which a ListMap needs.
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            // cardano-ledger `ToKeyValuePairs ConwayGenesis`.
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(constitution, forKey: .constitution)
            try c.encode(committee, forKey: .committee)
            try c.encode(poolVotingThresholds, forKey: .poolVotingThresholds)
            try c.encode(dRepVotingThresholds, forKey: .dRepVotingThresholds)
            try c.encode(committeeMinSize, forKey: .committeeMinSize)
            try c.encode(committeeMaxTermLength, forKey: .committeeMaxTermLength)
            try c.encode(govActionLifetime, forKey: .govActionLifetime)
            try c.encode(govActionDeposit, forKey: .govActionDeposit)
            try c.encode(dRepDeposit, forKey: .dRepDeposit)
            try c.encode(dRepActivity, forKey: .dRepActivity)
            try c.encodeLedgerRational(minFeeRefScriptCostPerByte, forKey: .minFeeRefScriptCostPerByte)
            try c.encode(plutusV3CostModel, forKey: .plutusV3CostModel)
            if !delegs.isEmpty { try c.encode(JSONListMap(delegs), forKey: .delegs) }
            if !initialDReps.isEmpty { try c.encode(JSONListMap(initialDReps), forKey: .initialDReps) }
            try c.encodeIfPresent(extraConfig, forKey: .extraConfig)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    // CBOR (cardano-ledger `ToCBOR ConwayGenesis`, at the Conway version):
    //   [ upgrade_conway_pparams, constitution, committee,
    //     delegs, initial_dreps, [] / [extra_config] ]
    // where upgrade_conway_pparams is
    //   [ pool_voting_thresholds, drep_voting_thresholds, committee_min_size,
    //     committee_max_term_length, gov_action_lifetime, gov_action_deposit,
    //     drep_deposit, drep_activity, min_fee_ref_script_cost_per_byte,
    //     [* int64] ]
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 6, "ConwayGenesis")
        let u = try conwayList(f[0], count: 10, "UpgradeConwayPParams")
        poolVotingThresholds = try ConwayGenesisPoolVotingThresholds(from: u[0])
        dRepVotingThresholds = try ConwayGenesisDRepVotingThresholds(from: u[1])
        committeeMinSize = try u[2].integer("ConwayGenesis committeeMinSize", as: UInt16.self)
        committeeMaxTermLength = try u[3].integer("ConwayGenesis committeeMaxTermLength", as: EpochInterval.self)
        govActionLifetime = try u[4].integer("ConwayGenesis govActionLifetime", as: EpochInterval.self)
        govActionDeposit = try u[5].integer("ConwayGenesis govActionDeposit", as: Coin.self)
        dRepDeposit = try u[6].integer("ConwayGenesis dRepDeposit", as: Coin.self)
        dRepActivity = try u[7].integer("ConwayGenesis dRepActivity", as: EpochInterval.self)
        minFeeRefScriptCostPerByte = try NonNegativeInterval.ledgerCBOR(
            u[8], "ConwayGenesis minFeeRefScriptCostPerByte")
        plutusV3CostModel = try conwayList(u[9], "ConwayGenesis plutusV3CostModel").map {
            try $0.integer("ConwayGenesis plutusV3CostModel", as: Int64.self)
        }
        constitution = try ConwayGenesisConstitution(from: f[1])
        committee = try Committee(from: f[2])
        delegs = try readListMap(f[3])
        initialDReps = try readListMap(f[4])
        let maybe = try conwayList(f[5], "ConwayGenesis extraConfig")
        guard maybe.count <= 1 else {
            throw CardanoCoreError.deserializeError("ConwayGenesis extraConfig: a StrictMaybe has at most one element")
        }
        extraConfig = try maybe.first.map { try ConwayGenesisExtraConfig(from: $0) }
    }

    public func toPrimitive() throws -> Primitive {
        let upgrade: Primitive = .list([
            try poolVotingThresholds.toPrimitive(),
            try dRepVotingThresholds.toPrimitive(),
            .uint(UInt64(committeeMinSize)),
            .uint(UInt64(committeeMaxTermLength)),
            .uint(UInt64(govActionLifetime)),
            .uint(govActionDeposit),
            .uint(dRepDeposit),
            .uint(UInt64(dRepActivity)),
            minFeeRefScriptCostPerByte.ledgerPrimitive(),
            // `encodeCostModel`: always a definite-length list.
            .list(plutusV3CostModel.map { .int($0) }),
        ])
        return .list([
            upgrade,
            try constitution.toPrimitive(),
            try committee.toPrimitive(),
            try listMapPrimitive(delegs),
            try listMapPrimitive(initialDReps),
            .list(try extraConfig.map { [try $0.toPrimitive()] } ?? []),
        ])
    }
}

// MARK: - Shared helpers

/// The elements of a definite or indefinite CBOR array; exactly `count` of
/// them when given.
func conwayList(_ p: Primitive, count: Int? = nil, _ label: String) throws -> [Primitive] {
    let items: [Primitive]
    switch p {
    case .list(let a): items = a
    case .indefiniteList(let a): items = a.getAll()
    default: throw CardanoCoreError.deserializeError("\(label): expected a list, got \(p)")
    }
    if let count, items.count != count {
        throw CardanoCoreError.deserializeError("\(label): expected \(count) elements, got \(items.count)")
    }
    return items
}

/// A CBOR byte string of exactly `size` bytes.
fileprivate func conwayBytes(_ p: Primitive, size: Int, _ label: String) throws -> Data {
    let data: Data
    switch p {
    case .bytes(let d): data = d
    case .byteArray(let b): data = Data(b)
    default: throw CardanoCoreError.deserializeError("\(label): expected bytes, got \(p)")
    }
    return try conwaySized(data, size, label)
}

fileprivate func conwaySized(_ data: Data, _ size: Int, _ label: String) throws -> Data {
    guard data.count == size else {
        throw CardanoCoreError.deserializeError("\(label): expected \(size) bytes, got \(data.count)")
    }
    return data
}

/// `hex` as exactly `size` bytes.
func conwayHash(hex: String, size: Int, _ label: String) throws -> Data {
    guard hex.count == size * 2, hex.allSatisfy(\.isHexDigit), let data = Data(hexString: hex),
          data.count == size else {
        throw CardanoCoreError.deserializeError("\(label): expected \(size) bytes of hex, got \"\(hex)\"")
    }
    return data
}

/// A ledger `Url`: text of at most 128 bytes.
fileprivate func conwayURL(_ url: String) throws -> String {
    guard url.utf8.count <= 128 else {
        throw CardanoCoreError.deserializeError("Anchor url: \(url.utf8.count) bytes is above 128")
    }
    return url
}

/// The elements of a set: an array, optionally under tag 258.
fileprivate func conwaySet(_ p: Primitive, _ label: String) throws -> [Primitive] {
    if case .cborTag(let t) = p {
        guard t.tag == 258 else {
            throw CardanoCoreError.deserializeError("\(label): a set's tag is 258, got \(t.tag)")
        }
        return try conwayList(t.value, label)
    }
    return try conwayList(p, label)
}

/// A set as the Conway ledger writes it: tag 258, and an indefinite-length
/// array past 23 elements.
fileprivate func conwaySetPrimitive(_ items: [Primitive]) -> Primitive {
    let list: Primitive = items.count <= 23 ? .list(items) : .indefiniteList(IndefiniteList(items))
    return .cborTag(CBORTag(tag: 258, value: list))
}

// MARK: - Sendable
extension ConwayGenesis: Sendable {}
