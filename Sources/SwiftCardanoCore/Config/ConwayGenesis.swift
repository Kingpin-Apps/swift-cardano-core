import Foundation

public struct ConwayGenesis: JSONLoadable {
    public let poolVotingThresholds: ConwayGenesisPoolVotingThresholds
    public let dRepVotingThresholds: ConwayGenesisDRepVotingThresholds
    public let committeeMinSize: Int
    public let committeeMaxTermLength: Int
    public let govActionLifetime: Int
    public let govActionDeposit: UInt64
    public let dRepDeposit: UInt64
    public let dRepActivity: Int
    public let minFeeRefScriptCostPerByte: Int64
    public let plutusV3CostModel: [Int]
    public let constitution: ConwayGenesisConstitution
    public let committee: Committee

    public init(
        poolVotingThresholds: ConwayGenesisPoolVotingThresholds,
        dRepVotingThresholds: ConwayGenesisDRepVotingThresholds,
        committeeMinSize: Int,
        committeeMaxTermLength: Int,
        govActionLifetime: Int,
        govActionDeposit: UInt64,
        dRepDeposit: UInt64,
        dRepActivity: Int,
        minFeeRefScriptCostPerByte: Int64,
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
            self.init(
                poolVotingThresholds:       try c.decode(ConwayGenesisPoolVotingThresholds.self, forKey: .poolVotingThresholds),
                dRepVotingThresholds:       try c.decode(ConwayGenesisDRepVotingThresholds.self, forKey: .dRepVotingThresholds),
                committeeMinSize:           try c.decode(Int.self, forKey: .committeeMinSize),
                committeeMaxTermLength:     try c.decode(Int.self, forKey: .committeeMaxTermLength),
                govActionLifetime:          try c.decode(Int.self, forKey: .govActionLifetime),
                govActionDeposit:           try c.decode(UInt64.self, forKey: .govActionDeposit),
                dRepDeposit:                try c.decode(UInt64.self, forKey: .dRepDeposit),
                dRepActivity:               try c.decode(Int.self, forKey: .dRepActivity),
                minFeeRefScriptCostPerByte: try c.decode(Int64.self, forKey: .minFeeRefScriptCostPerByte),
                plutusV3CostModel:          try c.decode([Int].self, forKey: .plutusV3CostModel),
                constitution:               try c.decode(ConwayGenesisConstitution.self, forKey: .constitution),
                committee:                  try c.decode(Committee.self, forKey: .committee)
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
        committeeMinSize         = Int(try Self.readUInt(f[2], label: "committeeMinSize"))
        committeeMaxTermLength   = Int(try Self.readUInt(f[3], label: "committeeMaxTermLength"))
        govActionLifetime        = Int(try Self.readUInt(f[4], label: "govActionLifetime"))
        govActionDeposit         = try Self.readUInt(f[5], label: "govActionDeposit")
        dRepDeposit              = try Self.readUInt(f[6], label: "dRepDeposit")
        dRepActivity             = Int(try Self.readUInt(f[7], label: "dRepActivity"))
        minFeeRefScriptCostPerByte = Int64(try Self.readUIntOrFraction(f[8], label: "minFeeRefScriptCostPerByte"))
        plutusV3CostModel        = try Self.readIntList(f[9])
        constitution             = try ConwayGenesisConstitution(from: f[10])
        committee                = try Committee(from: f[11])
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            try poolVotingThresholds.toPrimitive(),
            try dRepVotingThresholds.toPrimitive(),
            .uint(UInt64(committeeMinSize)),
            .uint(UInt64(committeeMaxTermLength)),
            .uint(UInt64(govActionLifetime)),
            .uint(govActionDeposit),
            .uint(dRepDeposit),
            .uint(UInt64(dRepActivity)),
            .uint(UInt64(minFeeRefScriptCostPerByte)),
            .list(plutusV3CostModel.map { .int(Int64($0)) }),
            try constitution.toPrimitive(),
            try committee.toPrimitive()
        ])
    }

    private static func readUInt(_ p: Primitive, label: String) throws -> UInt64 {
        switch p {
        case .uint(let u): return UInt64(u)
        case .int(let i) where i >= 0: return UInt64(i)
        default:
            throw CardanoCoreError.deserializeError("ConwayGenesis: expected uint for \(label)")
        }
    }

    // minFeeRefScriptCostPerByte may be a tag-30 rational in the ledger spec
    private static func readUIntOrFraction(_ p: Primitive, label: String) throws -> UInt64 {
        switch p {
        case .uint(let u): return UInt64(u)
        case .int(let i) where i >= 0: return UInt64(i)
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("ConwayGenesis: malformed tag-30 for \(label)")
            }
            let n: Double
            let d: Double
            switch arr[0] {
            case .int(let i): n = Double(i)
            case .uint(let u): n = Double(u)
            default: throw CardanoCoreError.deserializeError("ConwayGenesis: non-numeric numerator for \(label)")
            }
            switch arr[1] {
            case .int(let i): d = Double(i)
            case .uint(let u): d = Double(u)
            default: throw CardanoCoreError.deserializeError("ConwayGenesis: non-numeric denominator for \(label)")
            }
            return UInt64(n / d)
        default:
            throw CardanoCoreError.deserializeError("ConwayGenesis: expected uint or tag-30 for \(label)")
        }
    }

    private static func readIntList(_ p: Primitive) throws -> [Int] {
        guard case .list(let items) = p else {
            throw CardanoCoreError.deserializeError("ConwayGenesis: expected list for plutusV3CostModel")
        }
        return items.compactMap { item -> Int? in
            switch item {
            case .int(let i): return Int(i)
            case .uint(let u): return Int(u)
            default: return nil
            }
        }
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
            fraction(committeeNormal), fraction(committeeNoConfidence),
            fraction(hardForkInitiation), fraction(motionNoConfidence),
            fraction(ppSecurityGroup)
        ])
    }

    private static func readFraction(_ p: Primitive, label: String) throws -> Double {
        switch p {
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("ConwayGenesisPoolVotingThresholds: malformed tag-30 for \(label)")
            }
            let n: Double
            let d: Double
            switch arr[0] {
            case .int(let i): n = Double(i)
            case .uint(let u): n = Double(u)
            default: throw CardanoCoreError.deserializeError("non-numeric numerator for \(label)")
            }
            switch arr[1] {
            case .int(let i): d = Double(i)
            case .uint(let u): d = Double(u)
            default: throw CardanoCoreError.deserializeError("non-numeric denominator for \(label)")
            }
            return n / d
        case .float(let f): return f
        default:
            throw CardanoCoreError.deserializeError("ConwayGenesisPoolVotingThresholds: expected tag-30 for \(label)")
        }
    }

    private func fraction(_ d: Double) -> Primitive {
        let precision = 10_000_000
        let numerator = Int(d * Double(precision))
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        let g = gcd(abs(numerator), precision)
        return .cborTag(CBORTag(tag: 30, value: .list([.int(Int64(numerator / g)), .int(Int64(precision / g))])))
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
        func fraction(_ d: Double) -> Primitive {
            let precision = 10_000_000
            let numerator = Int(d * Double(precision))
            func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
            let g = gcd(abs(numerator), precision)
            return .cborTag(CBORTag(tag: 30, value: .list([.int(Int64(numerator / g)), .int(Int64(precision / g))])))
        }
        return .list([
            fraction(motionNoConfidence), fraction(committeeNormal), fraction(committeeNoConfidence),
            fraction(updateToConstitution), fraction(hardForkInitiation), fraction(ppNetworkGroup),
            fraction(ppEconomicGroup), fraction(ppTechnicalGroup), fraction(ppGovGroup),
            fraction(treasuryWithdrawal)
        ])
    }

    private static func readFraction(_ p: Primitive, label: String) throws -> Double {
        switch p {
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("DRepVotingThresholds: malformed tag-30 for \(label)")
            }
            let n: Double
            let d: Double
            switch arr[0] {
            case .int(let i): n = Double(i)
            case .uint(let u): n = Double(u)
            default: throw CardanoCoreError.deserializeError("non-numeric numerator for \(label)")
            }
            switch arr[1] {
            case .int(let i): d = Double(i)
            case .uint(let u): d = Double(u)
            default: throw CardanoCoreError.deserializeError("non-numeric denominator for \(label)")
            }
            return n / d
        case .float(let f): return f
        default:
            throw CardanoCoreError.deserializeError("DRepVotingThresholds: expected tag-30 for \(label)")
        }
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
        case .dict(let d): pairs = Array(d)
        case .orderedDict(let d): pairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Committee: expected map for members")
        }
        var membersResult: [String: Int] = [:]
        for (k, v) in pairs {
            let keyStr: String
            switch k {
            case .string(let s): keyStr = s
            case .bytes(let d): keyStr = d.map { String(format: "%02x", $0) }.joined()
            default: continue
            }
            switch v {
            case .int(let i): membersResult[keyStr] = Int(i)
            case .uint(let u): membersResult[keyStr] = Int(u)
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
            memberPairs.append((.string(k), .int(Int64(v))))
        }
        let thresholdPrim = Primitive.cborTag(
            CBORTag(tag: 30, value: .list([.int(Int64(threshold.numerator)), .int(Int64(threshold.denominator))]))
        )
        return .list([.frozenDict(Dictionary(uniqueKeysWithValues: memberPairs)), thresholdPrim])
    }

    private static func readThreshold(_ p: Primitive) throws -> Threshold {
        switch p {
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("Committee: malformed tag-30 threshold")
            }
            let num: Int
            let den: Int
            switch arr[0] {
            case .int(let i): num = Int(i)
            case .uint(let u): num = Int(u)
            default: throw CardanoCoreError.deserializeError("Committee: non-numeric numerator for threshold")
            }
            switch arr[1] {
            case .int(let i): den = Int(i)
            case .uint(let u): den = Int(u)
            default: throw CardanoCoreError.deserializeError("Committee: non-numeric denominator for threshold")
            }
            return Threshold(numerator: num, denominator: den)
        case .list(let arr) where arr.count == 2:
            let num: Int
            let den: Int
            switch arr[0] {
            case .int(let i): num = Int(i)
            case .uint(let u): num = Int(u)
            default: throw CardanoCoreError.deserializeError("Committee: non-numeric numerator for threshold")
            }
            switch arr[1] {
            case .int(let i): den = Int(i)
            case .uint(let u): den = Int(u)
            default: throw CardanoCoreError.deserializeError("Committee: non-numeric denominator for threshold")
            }
            return Threshold(numerator: num, denominator: den)
        default:
            throw CardanoCoreError.deserializeError("Committee: expected tag-30 threshold, got \(p)")
        }
    }
}

// MARK: - Sendable
extension ConwayGenesis: Sendable {}
extension ConwayGenesisPoolVotingThresholds: Sendable {}
extension ConwayGenesisDRepVotingThresholds: Sendable {}
extension ConwayGenesisConstitution: Sendable {}
extension ConwayGenesisAnchor: Sendable {}
