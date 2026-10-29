import Foundation

/// The ledger's `ConwayGenesis` (its `UpgradeConwayPParams`, constitution and
/// committee; cardano-ledger `Cardano.Ledger.Conway.Genesis`). Each integer
/// field has the width of its ledger type.
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
    public let minFeeRefScriptCostPerByte: Double
    public let plutusV3CostModel: [Int]
    public let constitution: ConwayGenesisConstitution
    public let committee: Committee

    public init(
        poolVotingThresholds: ConwayGenesisPoolVotingThresholds,
        dRepVotingThresholds: ConwayGenesisDRepVotingThresholds,
        committeeMinSize: UInt16,
        committeeMaxTermLength: EpochInterval,
        govActionLifetime: EpochInterval,
        govActionDeposit: Coin,
        dRepDeposit: Coin,
        dRepActivity: EpochInterval,
        minFeeRefScriptCostPerByte: Double,
        plutusV3CostModel: [Int],
        constitution: ConwayGenesisConstitution,
        committee: Committee
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
    }
}

public struct ConwayGenesisPoolVotingThresholds: Codable, Equatable, Hashable {
    public let committeeNormal: Double
    public let committeeNoConfidence: Double
    public let hardForkInitiation: Double
    public let motionNoConfidence: Double
    public let ppSecurityGroup: Double
}

public struct ConwayGenesisDRepVotingThresholds: Codable, Equatable, Hashable {
    public let motionNoConfidence: Double
    public let committeeNormal: Double
    public let committeeNoConfidence: Double
    public let updateToConstitution: Double
    public let hardForkInitiation: Double
    public let ppNetworkGroup: Double
    public let ppEconomicGroup: Double
    public let ppTechnicalGroup: Double
    public let ppGovGroup: Double
    public let treasuryWithdrawal: Double
}

public struct ConwayGenesisConstitution: Codable, Equatable, Hashable {
    public let anchor: ConwayGenesisAnchor
    public let script: String
}

public struct ConwayGenesisAnchor: Codable, Equatable, Hashable {
    public let dataHash: String
    public let url: String
}

// MARK: - Range-checked reads and writes

/// The numerator and denominator of a `#6.30([uint, uint])` rational, or of
/// the bare `[uint, uint]`, with a denominator above zero.
fileprivate func genesisRational(_ p: Primitive, _ label: String) throws -> (UInt64, UInt64) {
    let arr: [Primitive]
    switch p {
    case .cborTag(let t) where t.tag == 30:
        guard case .list(let a) = t.value else {
            throw CardanoCoreError.deserializeError("\(label): malformed tag-30 rational")
        }
        arr = a
    case .list(let a):
        arr = a
    default:
        throw CardanoCoreError.deserializeError("\(label): expected a tag-30 rational, got \(p)")
    }
    guard arr.count == 2 else {
        throw CardanoCoreError.deserializeError("\(label): a rational has 2 elements, got \(arr.count)")
    }
    let numerator = try arr[0].integer("\(label) numerator", as: UInt64.self)
    let denominator = try arr[1].integer("\(label) denominator", as: UInt64.self)
    guard denominator > 0 else {
        throw CardanoCoreError.deserializeError("\(label): denominator is zero")
    }
    return (numerator, denominator)
}

/// A voting threshold: a `unit_interval`, or a float in `0 ... 1`.
fileprivate func genesisThreshold(_ p: Primitive, _ label: String) throws -> Double {
    if case .float(let f) = p {
        guard f.isFinite, (0 ... 1).contains(f) else {
            throw CardanoCoreError.deserializeError("\(label): \(f) is not in 0 ... 1")
        }
        return f
    }
    let (n, d) = try genesisRational(p, label)
    guard n <= d else {
        throw CardanoCoreError.deserializeError("\(label): \(n)/\(d) is above one")
    }
    return Double(n) / Double(d)
}

/// A voting threshold written as a tag-30 rational over 10^7.
///
/// - Throws: When `d` is not finite or not in `0 ... 1`.
fileprivate func genesisThresholdFraction(_ d: Double, _ label: String) throws -> Primitive {
    let precision = 10_000_000
    guard d.isFinite, (0 ... 1).contains(d),
        let numerator = Int(exactly: (d * Double(precision)).rounded(.towardZero))
    else {
        throw CardanoCoreError.valueError("\(label): \(d) is not in 0 ... 1")
    }
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    let g = gcd(numerator, precision)
    return .cborTag(CBORTag(tag: 30, value: .list([.integer(numerator / g), .integer(precision / g)])))
}

// MARK: - CBOR (Haskell ToCBOR field order)
//
// ConwayGenesis encodes as a list of 12 fields (cardano-ledger conway):
//   [0] poolVotingThresholds    [1] dRepVotingThresholds  [2] committeeMinSize
//   [3] committeeMaxTermLength  [4] govActionLifetime     [5] govActionDeposit
//   [6] dRepDeposit             [7] dRepActivity          [8] minFeeRefScriptCostPerByte
//   [9] plutusV3CostModel       [10] constitution         [11] committee
//
// NOTE: Verify field order against live node output; adjust if decoding fails.

extension ConwayGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case poolVotingThresholds, dRepVotingThresholds, committeeMinSize
        case committeeMaxTermLength, govActionLifetime, govActionDeposit
        case dRepDeposit, dRepActivity, minFeeRefScriptCostPerByte
        case plutusV3CostModel, constitution, committee
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let poolVotingThresholds = try c.decode(ConwayGenesisPoolVotingThresholds.self, forKey: .poolVotingThresholds)
            let dRepVotingThresholds = try c.decode(ConwayGenesisDRepVotingThresholds.self, forKey: .dRepVotingThresholds)
            // UnitIntervals in the ledger.
            let p = poolVotingThresholds, d = dRepVotingThresholds
            for value in [p.committeeNormal, p.committeeNoConfidence, p.hardForkInitiation, p.motionNoConfidence,
                          p.ppSecurityGroup, d.motionNoConfidence, d.committeeNormal, d.committeeNoConfidence,
                          d.updateToConstitution, d.hardForkInitiation, d.ppNetworkGroup, d.ppEconomicGroup,
                          d.ppTechnicalGroup, d.ppGovGroup, d.treasuryWithdrawal]
            where !value.isFinite || value < 0 || value > 1 {
                throw CardanoCoreError.deserializeError("ConwayGenesis voting threshold: \(value) is not in 0 ... 1")
            }
            self.init(
                poolVotingThresholds:       poolVotingThresholds,
                dRepVotingThresholds:       dRepVotingThresholds,
                committeeMinSize:           try c.decode(UInt16.self, forKey: .committeeMinSize),
                committeeMaxTermLength:     try c.decode(EpochInterval.self, forKey: .committeeMaxTermLength),
                govActionLifetime:          try c.decode(EpochInterval.self, forKey: .govActionLifetime),
                govActionDeposit:           try c.decode(Coin.self, forKey: .govActionDeposit),
                dRepDeposit:                try c.decode(Coin.self, forKey: .dRepDeposit),
                dRepActivity:               try c.decode(EpochInterval.self, forKey: .dRepActivity),
                minFeeRefScriptCostPerByte: try Self.nonNegative(
                    try c.decode(Double.self, forKey: .minFeeRefScriptCostPerByte)),
                plutusV3CostModel:          try c.decode([Int].self, forKey: .plutusV3CostModel),
                constitution:               try c.decode(ConwayGenesisConstitution.self, forKey: .constitution),
                committee:                  try c.decode(Committee.self, forKey: .committee)
            )
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(poolVotingThresholds, forKey: .poolVotingThresholds)
            try c.encode(dRepVotingThresholds, forKey: .dRepVotingThresholds)
            try c.encode(committeeMinSize, forKey: .committeeMinSize)
            try c.encode(committeeMaxTermLength, forKey: .committeeMaxTermLength)
            try c.encode(govActionLifetime, forKey: .govActionLifetime)
            try c.encode(govActionDeposit, forKey: .govActionDeposit)
            try c.encode(dRepDeposit, forKey: .dRepDeposit)
            try c.encode(dRepActivity, forKey: .dRepActivity)
            try c.encode(minFeeRefScriptCostPerByte, forKey: .minFeeRefScriptCostPerByte)
            try c.encode(plutusV3CostModel, forKey: .plutusV3CostModel)
            try c.encode(constitution, forKey: .constitution)
            try c.encode(committee, forKey: .committee)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 12 else {
            throw CardanoCoreError.deserializeError(
                "ConwayGenesis: expected list of 12+ elements, got \(primitive)")
        }
        poolVotingThresholds     = try ConwayGenesisPoolVotingThresholds(from: f[0])
        dRepVotingThresholds     = try ConwayGenesisDRepVotingThresholds(from: f[1])
        // Ranges as the ledger's ConwayGenesis holds them: Word16 for the
        // committee size, EpochInterval (Word32) for the periods, Coin for
        // the deposits.
        committeeMinSize         = try f[2].integer("ConwayGenesis committeeMinSize", as: UInt16.self)
        committeeMaxTermLength   = try f[3].integer("ConwayGenesis committeeMaxTermLength", as: EpochInterval.self)
        govActionLifetime        = try f[4].integer("ConwayGenesis govActionLifetime", as: EpochInterval.self)
        govActionDeposit         = try f[5].integer("ConwayGenesis govActionDeposit", as: Coin.self)
        dRepDeposit              = try f[6].integer("ConwayGenesis dRepDeposit", as: Coin.self)
        dRepActivity             = try f[7].integer("ConwayGenesis dRepActivity", as: EpochInterval.self)
        minFeeRefScriptCostPerByte = try Self.readUIntOrFraction(f[8], label: "minFeeRefScriptCostPerByte")
        plutusV3CostModel        = try Self.readIntList(f[9])
        constitution             = try ConwayGenesisConstitution(from: f[10])
        committee                = try Committee(from: f[11])
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            try poolVotingThresholds.toPrimitive(),
            try dRepVotingThresholds.toPrimitive(),
            .integer(committeeMinSize),
            .integer(committeeMaxTermLength),
            .integer(govActionLifetime),
            .uint(govActionDeposit),
            .uint(dRepDeposit),
            .integer(dRepActivity),
            try Self.minFeeRefScriptPrimitive(minFeeRefScriptCostPerByte),
            .list(plutusV3CostModel.map { .integer($0) }),
            try constitution.toPrimitive(),
            try committee.toPrimitive()
        ])
    }

    // minFeeRefScriptCostPerByte is a `nonnegative_interval` in the ledger:
    // a tag-30 rational, read whole. A bare integer is read as itself.
    private static func readUIntOrFraction(_ p: Primitive, label: String) throws -> Double {
        switch p {
        case .uint, .int, .bigInt, .bigUInt:
            return Double(try p.integer("ConwayGenesis \(label)", as: UInt64.self))
        default:
            let (n, d) = try genesisRational(p, "ConwayGenesis \(label)")
            return Double(n) / Double(d)
        }
    }

    /// A non-negative, finite value; what a `NonNegativeInterval` holds.
    private static func nonNegative(_ value: Double) throws -> Double {
        guard value.isFinite, value >= 0 else {
            throw CardanoCoreError.deserializeError(
                "ConwayGenesis minFeeRefScriptCostPerByte: \(value) is not a non-negative number")
        }
        return value
    }

    /// `value` as the tag-30 rational the ledger writes.
    ///
    /// - Throws: When `value` cannot be written as a `NonNegativeInterval`.
    private static func minFeeRefScriptPrimitive(_ value: Double) throws -> Primitive {
        guard let interval = doubleToNonNegativeInterval(value) else {
            throw CardanoCoreError.valueError(
                "ConwayGenesis minFeeRefScriptCostPerByte: \(value) is not a non-negative interval")
        }
        return .cborTag(CBORTag(tag: 30, value: .list([
            .integer(interval.lowerBound), .integer(interval.upperBound)
        ])))
    }

    private static func readIntList(_ p: Primitive) throws -> [Int] {
        guard case .list(let items) = p else {
            throw CardanoCoreError.deserializeError("ConwayGenesis: expected list for plutusV3CostModel")
        }
        // Cost model parameters are `int64` in the CDDL.
        return try items.map { try Int($0.integer("ConwayGenesis plutusV3CostModel", as: Int64.self)) }
    }
}

// MARK: - Voting threshold types CBOR
// Each encodes as a list of tag-30 rationals.

extension ConwayGenesisPoolVotingThresholds {
    // CBOR order (cardano-ledger PoolVotingThresholds ToCBOR):
    //   [0] committeeNormal  [1] committeeNoConfidence  [2] hardForkInitiation
    //   [3] motionNoConfidence  [4] ppSecurityGroup
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 5 else {
            throw CardanoCoreError.deserializeError("ConwayGenesisPoolVotingThresholds: expected list of 5 elements")
        }
        committeeNormal      = try Self.readFraction(f[0], label: "committeeNormal")
        committeeNoConfidence = try Self.readFraction(f[1], label: "committeeNoConfidence")
        hardForkInitiation   = try Self.readFraction(f[2], label: "hardForkInitiation")
        motionNoConfidence   = try Self.readFraction(f[3], label: "motionNoConfidence")
        ppSecurityGroup      = try Self.readFraction(f[4], label: "ppSecurityGroup")
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            try fraction(committeeNormal), try fraction(committeeNoConfidence),
            try fraction(hardForkInitiation), try fraction(motionNoConfidence),
            try fraction(ppSecurityGroup)
        ])
    }

    private static func readFraction(_ p: Primitive, label: String) throws -> Double {
        try genesisThreshold(p, "ConwayGenesisPoolVotingThresholds \(label)")
    }

    private func fraction(_ d: Double) throws -> Primitive {
        try genesisThresholdFraction(d, "ConwayGenesisPoolVotingThresholds")
    }
}

extension ConwayGenesisDRepVotingThresholds {
    // CBOR order (cardano-ledger DRepVotingThresholds ToCBOR):
    //   [0] motionNoConfidence  [1] committeeNormal  [2] committeeNoConfidence
    //   [3] updateToConstitution  [4] hardForkInitiation  [5] ppNetworkGroup
    //   [6] ppEconomicGroup  [7] ppTechnicalGroup  [8] ppGovGroup  [9] treasuryWithdrawal
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 10 else {
            throw CardanoCoreError.deserializeError("ConwayGenesisDRepVotingThresholds: expected list of 10 elements")
        }
        motionNoConfidence   = try Self.readFraction(f[0], label: "motionNoConfidence")
        committeeNormal      = try Self.readFraction(f[1], label: "committeeNormal")
        committeeNoConfidence = try Self.readFraction(f[2], label: "committeeNoConfidence")
        updateToConstitution = try Self.readFraction(f[3], label: "updateToConstitution")
        hardForkInitiation   = try Self.readFraction(f[4], label: "hardForkInitiation")
        ppNetworkGroup       = try Self.readFraction(f[5], label: "ppNetworkGroup")
        ppEconomicGroup      = try Self.readFraction(f[6], label: "ppEconomicGroup")
        ppTechnicalGroup     = try Self.readFraction(f[7], label: "ppTechnicalGroup")
        ppGovGroup           = try Self.readFraction(f[8], label: "ppGovGroup")
        treasuryWithdrawal   = try Self.readFraction(f[9], label: "treasuryWithdrawal")
    }

    public func toPrimitive() throws -> Primitive {
        func fraction(_ d: Double) throws -> Primitive {
            try genesisThresholdFraction(d, "ConwayGenesisDRepVotingThresholds")
        }
        return .list([
            try fraction(motionNoConfidence), try fraction(committeeNormal), try fraction(committeeNoConfidence),
            try fraction(updateToConstitution), try fraction(hardForkInitiation), try fraction(ppNetworkGroup),
            try fraction(ppEconomicGroup), try fraction(ppTechnicalGroup), try fraction(ppGovGroup),
            try fraction(treasuryWithdrawal)
        ])
    }

    private static func readFraction(_ p: Primitive, label: String) throws -> Double {
        try genesisThreshold(p, "DRepVotingThresholds \(label)")
    }
}

// MARK: - ConwayGenesisConstitution CBOR
// Encodes as [[url, dataHash], scriptHash?] — same as LedgerConstitution anchor format.
extension ConwayGenesisConstitution {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 1 else {
            throw CardanoCoreError.deserializeError("ConwayGenesisConstitution: expected list")
        }
        anchor = try ConwayGenesisAnchor(from: f[0])
        // script hash is optional; may be StrictMaybe [] = none or [hash] = present
        if f.count >= 2 {
            switch f[1] {
            case .list(let maybe) where !maybe.isEmpty:
                script = try Self.readHexOrString(maybe[0])
            case .bytes(let d):
                script = d.map { String(format: "%02x", $0) }.joined()
            case .string(let s):
                script = s
            default:
                script = ""
            }
        } else {
            script = ""
        }
    }

    public func toPrimitive() throws -> Primitive {
        let anchorPrim = try anchor.toPrimitive()
        let scriptPrim: Primitive = script.isEmpty ? .list([]) : .list([.string(script)])
        return .list([anchorPrim, scriptPrim])
    }

    private static func readHexOrString(_ p: Primitive) throws -> String {
        switch p {
        case .string(let s): return s
        case .bytes(let d): return d.map { String(format: "%02x", $0) }.joined()
        default:
            throw CardanoCoreError.deserializeError("ConwayGenesisConstitution: expected string or bytes for script hash")
        }
    }
}

// MARK: - ConwayGenesisAnchor CBOR
// Encodes as [url, dataHash].
extension ConwayGenesisAnchor {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 2 else {
            throw CardanoCoreError.deserializeError("ConwayGenesisAnchor: expected [url, dataHash]")
        }
        guard case .string(let u) = f[0] else {
            throw CardanoCoreError.deserializeError("ConwayGenesisAnchor: expected string for url")
        }
        url = u
        switch f[1] {
        case .string(let s): dataHash = s
        case .bytes(let d): dataHash = d.map { String(format: "%02x", $0) }.joined()
        case .byteArray(let b): dataHash = b.map { String(format: "%02x", $0) }.joined()
        default:
            throw CardanoCoreError.deserializeError("ConwayGenesisAnchor: expected string/bytes for dataHash")
        }
    }

    public func toPrimitive() throws -> Primitive {
        .list([.string(url), .string(dataHash)])
    }
}

// MARK: - Committee CBOR (genesis initial committee)
// Wire format: [{ cold_credential → epochNo }, threshold]
// where threshold encodes as tag-30 [numerator, denominator].
extension Committee {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 2 else {
            throw CardanoCoreError.deserializeError("Committee: expected [members, threshold]")
        }
        // members map: { cold_cred → expiry_epoch }
        let pairs: [(Primitive, Primitive)]
        switch f[0] {
        case .dict(let d), .frozenDict(let d): pairs = Array(d)
        case .orderedDict(let d): pairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Committee: expected map for members")
        }
        var membersResult: [String: EpochNumber] = [:]
        for (k, v) in pairs {
            let keyStr: String
            switch k {
            case .string(let s): keyStr = s
            case .bytes(let d): keyStr = d.map { String(format: "%02x", $0) }.joined()
            default: continue
            }
            switch v {
            case .int, .uint, .bigInt, .bigUInt:
                // An expiry epoch: EpochNo, a Word64.
                membersResult[keyStr] = try v.integer("Committee member epoch", as: EpochNumber.self)
            default: break
            }
        }
        members = membersResult

        // threshold: tag-30 rational
        threshold = try Self.readThreshold(f[1])
    }

    public func toPrimitive() throws -> Primitive {
        var memberPairs: [(Primitive, Primitive)] = []
        for (k, v) in members {
            memberPairs.append((.string(k), .integer(v)))
        }
        let thresholdPrim = Primitive.cborTag(
            CBORTag(tag: 30, value: .list([.integer(threshold.numerator), .integer(threshold.denominator)]))
        )
        return .list([.frozenDict(Dictionary(uniqueKeysWithValues: memberPairs)), thresholdPrim])
    }

    private static func readThreshold(_ p: Primitive) throws -> Threshold {
        // A unit_interval: Word64 numerator and denominator.
        let (num, den) = try genesisRational(p, "Committee threshold")
        guard num <= den else {
            throw CardanoCoreError.deserializeError("Committee threshold: \(num)/\(den) is above one")
        }
        return try Threshold(numerator: num, denominator: den)
    }
}

// MARK: - Sendable
extension ConwayGenesis: Sendable {}
extension ConwayGenesisPoolVotingThresholds: Sendable {}
extension ConwayGenesisDRepVotingThresholds: Sendable {}
extension ConwayGenesisConstitution: Sendable {}
extension ConwayGenesisAnchor: Sendable {}
