import Foundation
@preconcurrency import BigInt

/// The ledger's `ShelleyGenesis` (cardano-ledger, `Cardano.Ledger.Shelley.Genesis`).
/// Each integer field has the width of its ledger type.
public struct ShelleyGenesis: JSONLoadable {
    public let activeSlotsCoeff: Double
    public let protocolParams: ProtocolParams
    public let genDelegs: [String: GenDelegation]
    /// `Word64`.
    public let updateQuorum: UInt64
    public let networkId: String
    /// `ListMap Addr Coin`: each balance a `Coin` (`Word64`).
    public let initialFunds: [String: Coin]
    /// `Word64`.
    public let maxLovelaceSupply: UInt64
    /// `Word32`.
    public let networkMagic: UInt32
    /// `EpochSize`, a `Word64`.
    public let epochLength: UInt64
    public let systemStart: String
    /// `Word64`.
    public let slotsPerKESPeriod: UInt64
    /// Seconds, as the ledger's `NominalDiffTimeMicro`: a fixed-point number
    /// with microsecond precision, written in JSON as seconds (`1`, `0.2`) and
    /// in CBOR as a whole number of microseconds.
    public let slotLength: Decimal
    /// `Word64`.
    public let maxKESEvolutions: UInt64
    /// `NonZero Word64`: never zero.
    public let securityParam: UInt64

    public init(
        activeSlotsCoeff: Double,
        protocolParams: ProtocolParams,
        genDelegs: [String: GenDelegation],
        updateQuorum: UInt64,
        networkId: String,
        initialFunds: [String: Coin],
        maxLovelaceSupply: UInt64,
        networkMagic: UInt32,
        epochLength: UInt64,
        systemStart: String,
        slotsPerKESPeriod: UInt64,
        slotLength: Decimal,
        maxKESEvolutions: UInt64,
        securityParam: UInt64
    ) {
        self.activeSlotsCoeff = activeSlotsCoeff
        self.protocolParams = protocolParams
        self.genDelegs = genDelegs
        self.updateQuorum = updateQuorum
        self.networkId = networkId
        self.initialFunds = initialFunds
        self.maxLovelaceSupply = maxLovelaceSupply
        self.networkMagic = networkMagic
        self.epochLength = epochLength
        self.systemStart = systemStart
        self.slotsPerKESPeriod = slotsPerKESPeriod
        self.slotLength = slotLength
        self.maxKESEvolutions = maxKESEvolutions
        self.securityParam = securityParam
    }
}

/// The ledger's `ShelleyPParams`, as Shelley genesis holds them. Each integer
/// field has the width of its ledger type.
public struct ProtocolParams: Codable, Equatable, Hashable {
    /// `ProtVer`: a `Version` (a `Word32`) and a `Word32` minor.
    public struct ProtocolVersion: Codable, Equatable, Hashable {
        public let minor: UInt32
        public let major: UInt32

        public init(minor: UInt32, major: UInt32) {
            self.minor = minor
            self.major = major
        }
    }

    public struct ExtraEntropy: Codable, Equatable, Hashable {
        public let tag: String
    }

    public let protocolVersion: ProtocolVersion
    public let decentralisationParam: Double
    /// `EpochInterval`, a `Word32`.
    public let eMax: EpochInterval
    public let extraEntropy: ExtraEntropy
    /// `Word32`.
    public let maxTxSize: UInt32
    /// `Word32`.
    public let maxBlockBodySize: UInt32
    /// `Word16`.
    public let maxBlockHeaderSize: UInt16
    /// `CoinPerByte`, a `Coin`.
    public let minFeeA: Coin
    /// `Coin`.
    public let minFeeB: Coin
    public let minUTxOValue: Coin
    public let poolDeposit: Coin
    public let minPoolCost: Coin
    public let keyDeposit: Coin
    /// `Word16`.
    public let nOpt: UInt16
    public let rho: Double
    public let tau: Double
    public let a0: Double
}

public struct GenDelegation: Codable, Equatable, Hashable {
    public let delegate: String
    public let vrf: String
}

// MARK: - CBOR (Haskell ToCBOR field order)
//
// ShelleyGenesis encodes as a list of 15 fields in this order (cardano-ledger):
//   [0] systemStart  [1] networkMagic  [2] networkId  [3] activeSlotsCoeff
//   [4] securityParam  [5] epochLength  [6] slotsPerKESPeriod  [7] maxKESEvolutions
//   [8] slotLength  [9] updateQuorum  [10] maxLovelaceSupply  [11] protocolParams
//   [12] genDelegs  [13] initialFunds  [14] staking (skipped)
//
// NOTE: Verify field order against live node output; adjust if decoding fails.

extension ShelleyGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case activeSlotsCoeff, protocolParams, genDelegs, updateQuorum, networkId
        case initialFunds, maxLovelaceSupply, networkMagic, epochLength
        case systemStart, slotsPerKESPeriod, slotLength, maxKESEvolutions, securityParam
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let securityParam = try c.decode(UInt64.self, forKey: .securityParam)
            guard securityParam > 0 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis securityParam: must not be zero")
            }
            // A PositiveUnitInterval in the ledger.
            let activeSlotsCoeff = try c.decode(Double.self, forKey: .activeSlotsCoeff)
            guard activeSlotsCoeff > 0, activeSlotsCoeff <= 1 else {
                throw CardanoCoreError.deserializeError(
                    "ShelleyGenesis activeSlotsCoeff: \(activeSlotsCoeff) is not in (0, 1]")
            }
            let protocolParams = try c.decode(ProtocolParams.self, forKey: .protocolParams)
            try protocolParams.checkRationalRanges()
            self.init(
                activeSlotsCoeff:  activeSlotsCoeff,
                protocolParams:    protocolParams,
                genDelegs:         try c.decode([String: GenDelegation].self, forKey: .genDelegs),
                updateQuorum:      try c.decode(UInt64.self, forKey: .updateQuorum),
                networkId:         try c.decode(String.self, forKey: .networkId),
                initialFunds:      try c.decode([String: Coin].self, forKey: .initialFunds),
                maxLovelaceSupply: try c.decode(UInt64.self, forKey: .maxLovelaceSupply),
                networkMagic:      try c.decode(UInt32.self, forKey: .networkMagic),
                epochLength:       try c.decode(UInt64.self, forKey: .epochLength),
                systemStart:       try c.decode(String.self, forKey: .systemStart),
                slotsPerKESPeriod: try c.decode(UInt64.self, forKey: .slotsPerKESPeriod),
                slotLength:        Self.truncatedToMicroseconds(try c.decode(Decimal.self, forKey: .slotLength)),
                maxKESEvolutions:  try c.decode(UInt64.self, forKey: .maxKESEvolutions),
                securityParam:     securityParam
            )
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(activeSlotsCoeff, forKey: .activeSlotsCoeff)
            try c.encode(protocolParams, forKey: .protocolParams)
            try c.encode(genDelegs, forKey: .genDelegs)
            try c.encode(updateQuorum, forKey: .updateQuorum)
            try c.encode(networkId, forKey: .networkId)
            try c.encode(initialFunds, forKey: .initialFunds)
            try c.encode(maxLovelaceSupply, forKey: .maxLovelaceSupply)
            try c.encode(networkMagic, forKey: .networkMagic)
            try c.encode(epochLength, forKey: .epochLength)
            try c.encode(systemStart, forKey: .systemStart)
            try c.encode(slotsPerKESPeriod, forKey: .slotsPerKESPeriod)
            try c.encode(slotLength, forKey: .slotLength)
            try c.encode(maxKESEvolutions, forKey: .maxKESEvolutions)
            try c.encode(securityParam, forKey: .securityParam)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 14 else {
            throw CardanoCoreError.deserializeError(
                "ShelleyGenesis: expected list of 14+ elements, got \(primitive)")
        }
        systemStart   = try Self.readString(f[0], label: "systemStart")
        networkMagic  = try f[1].integer("ShelleyGenesis networkMagic", as: UInt32.self)
        networkId     = Self.decodeNetworkId(f[2])
        // A PositiveUnitInterval in the ledger.
        activeSlotsCoeff = try Self.readFraction(f[3], label: "activeSlotsCoeff")
        guard activeSlotsCoeff > 0 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis: activeSlotsCoeff must be above zero")
        }
        securityParam = try f[4].integer("ShelleyGenesis securityParam", as: UInt64.self)
        guard securityParam > 0 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis securityParam: must not be zero")
        }
        epochLength   = try f[5].integer("ShelleyGenesis epochLength", as: UInt64.self)
        slotsPerKESPeriod = try f[6].integer("ShelleyGenesis slotsPerKESPeriod", as: UInt64.self)
        maxKESEvolutions  = try f[7].integer("ShelleyGenesis maxKESEvolutions", as: UInt64.self)
        slotLength    = try Self.readSlotLength(f[8])
        updateQuorum  = try f[9].integer("ShelleyGenesis updateQuorum", as: UInt64.self)
        maxLovelaceSupply = try Self.readUInt(f[10], label: "maxLovelaceSupply")
        protocolParams = try ProtocolParams(from: f[11])
        genDelegs     = try Self.readGenDelegs(f[12])
        initialFunds  = try Self.readInitialFunds(f[13])
    }

    public func toPrimitive() throws -> Primitive {
        let networkIdPrim: Primitive = networkId == "Mainnet" ? .uint(1) : .uint(0)
        let genDelegsList: Primitive = .list(genDelegs.map { k, v in
            .list([.string(k), .list([.string(v.delegate), .string(v.vrf)])])
        })
        let initialFundsList: Primitive = .list(initialFunds.map { k, v in
            .list([.string(k), .integer(v)])
        })
        var elements: [Primitive] = []
        elements.append(.string(systemStart))
        elements.append(.integer(networkMagic))
        elements.append(networkIdPrim)
        elements.append(try Self.fractionPrimitive(activeSlotsCoeff, label: "activeSlotsCoeff"))
        elements.append(.integer(securityParam))
        elements.append(.integer(epochLength))
        elements.append(.integer(slotsPerKESPeriod))
        elements.append(.integer(maxKESEvolutions))
        elements.append(try Self.slotLengthPrimitive(slotLength))
        elements.append(.integer(updateQuorum))
        elements.append(.uint(maxLovelaceSupply))
        elements.append(try protocolParams.toPrimitive())
        elements.append(genDelegsList)
        elements.append(initialFundsList)
        elements.append(.list([])) // staking placeholder
        return .list(elements)
    }

    // MARK: - Helpers

    private static func readString(_ p: Primitive, label: String) throws -> String {
        switch p {
        case .string(let s):
            return s
        case .list(let elems) where elems.count == 3 && label == "systemStart":
            // Haskell UTCTime: [year: uint, dayOfYear: uint, picosecondsOfDay: uint]
            return try formatUTCTime(elems)
        default:
            throw CardanoCoreError.deserializeError("ShelleyGenesis: expected string for \(label)")
        }
    }

    private static func formatUTCTime(_ elems: [Primitive]) throws -> String {
        // Calendar arithmetic is only meaningful, and only safe, for years
        // a calendar can hold; a day of the year runs 1 ... 366.
        let year = try elems[0].integer("ShelleyGenesis systemStart.year", as: UInt16.self)
        let dayOfYear = try elems[1].integer("ShelleyGenesis systemStart.dayOfYear", as: UInt16.self)
        let picosOfDay = try readUInt(elems[2], label: "systemStart.picosOfDay")
        guard (1 ... 366).contains(dayOfYear) else {
            throw CardanoCoreError.deserializeError(
                "ShelleyGenesis: systemStart day of year \(dayOfYear) is not in 1 ... 366")
        }
        var components = DateComponents()
        components.year = Int(year)
        components.day = Int(dayOfYear)
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "UTC")
        guard let date = components.date else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis: invalid systemStart UTCTime \(elems)")
        }
        let secondsOfDay = Double(picosOfDay) / 1e12
        let full = date.addingTimeInterval(secondsOfDay)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: full)
    }

    private static func readUInt(_ p: Primitive, label: String) throws -> UInt64 {
        try p.integer("ShelleyGenesis \(label)", as: UInt64.self)
    }

    /// A unit interval: the active slot coefficient.
    private static func readFraction(_ p: Primitive, label: String) throws -> Double {
        try readFraction2(p, label: label, atMostOne: true)
    }

    // MARK: slotLength (NominalDiffTimeMicro)

    /// The most significant digits a `Decimal` holds exactly.
    private static let decimalDigits = 38

    /// `seconds` cut down to whole microseconds, as the ledger's JSON reader
    /// does (`realToFrac` into `Micro` floors).
    static func truncatedToMicroseconds(_ seconds: Decimal) -> Decimal {
        var micro = seconds * 1_000_000
        var whole = Decimal()
        NSDecimalRound(&whole, &micro, 0, .down)
        return whole / 1_000_000
    }

    /// The ledger writes `NominalDiffTimeMicro` in CBOR as its `Micro`: a
    /// whole number of microseconds, of any size.
    private static func readSlotLength(_ p: Primitive) throws -> Decimal {
        guard let micro = p.integerValue else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis slotLength: expected an integer, got \(p)")
        }
        let digits = micro.magnitude.description
        guard digits.count <= decimalDigits, let decimal = Decimal(string: micro.description) else {
            throw CardanoCoreError.deserializeError(
                "ShelleyGenesis slotLength: \(micro) microseconds is too large to hold")
        }
        return decimal / 1_000_000
    }

    /// `seconds` as the whole number of microseconds the ledger writes.
    ///
    /// - Throws: When `seconds` is not a whole number of microseconds.
    static func slotLengthPrimitive(_ seconds: Decimal) throws -> Primitive {
        var micro = seconds * 1_000_000
        var whole = Decimal()
        NSDecimalRound(&whole, &micro, 0, .plain)
        guard whole == micro, !micro.isNaN, let value = BigInt(whole.description) else {
            throw CardanoCoreError.valueError(
                "ShelleyGenesis slotLength: \(seconds) is not a whole number of microseconds")
        }
        return .integer(value)
    }

    private static func decodeNetworkId(_ p: Primitive) -> String {
        switch p {
        case .uint(0): return "Testnet"
        case .uint(1): return "Mainnet"
        case .string(let s): return s
        default: return "Testnet"
        }
    }

    // genDelegs: list of [[keyHash, [delegate, vrf]]] or map {bytes → [bytes, bytes]}
    private static func readGenDelegs(_ p: Primitive) throws -> [String: GenDelegation] {
        var result: [String: GenDelegation] = [:]
        switch p {
        case .list(let pairs):
            for pair in pairs {
                guard case .list(let kv) = pair, kv.count >= 2 else { continue }
                let key = try readHexOrString(kv[0])
                guard case .list(let vals) = kv[1], vals.count >= 2 else { continue }
                let delegate = try readHexOrString(vals[0])
                let vrf = try readHexOrString(vals[1])
                result[key] = GenDelegation(delegate: delegate, vrf: vrf)
            }
        case .dict(let d):
            for (k, v) in d {
                let key = try readHexOrString(k)
                guard case .list(let vals) = v, vals.count >= 2 else { continue }
                let delegate = try readHexOrString(vals[0])
                let vrf = try readHexOrString(vals[1])
                result[key] = GenDelegation(delegate: delegate, vrf: vrf)
            }
        case .orderedDict(let d):
            for (k, v) in d {
                let key = try readHexOrString(k)
                guard case .list(let vals) = v, vals.count >= 2 else { continue }
                let delegate = try readHexOrString(vals[0])
                let vrf = try readHexOrString(vals[1])
                result[key] = GenDelegation(delegate: delegate, vrf: vrf)
            }
        default: break
        }
        return result
    }

    private static func readInitialFunds(_ p: Primitive) throws -> [String: Coin] {
        var result: [String: Coin] = [:]
        switch p {
        case .list(let pairs):
            for pair in pairs {
                guard case .list(let kv) = pair, kv.count >= 2 else { continue }
                let key = try readHexOrString(kv[0])
                switch kv[1] {
                case .uint, .int, .bigInt, .bigUInt: result[key] = try readUInt(kv[1], label: "initialFunds")
                default: break
                }
            }
        case .dict(let d):
            for (k, v) in d {
                let key = try readHexOrString(k)
                switch v {
                case .uint, .int, .bigInt, .bigUInt: result[key] = try readUInt(v, label: "initialFunds")
                default: break
                }
            }
        default: break
        }
        return result
    }

    private static func readHexOrString(_ p: Primitive) throws -> String {
        switch p {
        case .string(let s): return s
        case .bytes(let d): return d.map { String(format: "%02x", $0) }.joined()
        case .byteArray(let b): return b.map { String(format: "%02x", $0) }.joined()
        default:
            throw CardanoCoreError.deserializeError("ShelleyGenesis: expected string or bytes key")
        }
    }

    private static func fractionPrimitive(_ d: Double, label: String) throws -> Primitive {
        try fractionPrimitive2(d, label: label)
    }
}

// MARK: - ProtocolParams CBOR
//
// ShelleyPParams encodes as a list of 17 fields (cardano-ledger ToCBOR):
//   [0] minFeeA  [1] minFeeB  [2] maxBlockBodySize  [3] maxTxSize  [4] maxBlockHeaderSize
//   [5] keyDeposit  [6] poolDeposit  [7] eMax  [8] nOpt
//   [9] a0  [10] rho  [11] tau  [12] decentralisationParam  [13] extraEntropy
//   [14] protocolVersion  [15] minUTxOValue  [16] minPoolCost

extension ProtocolParams {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 17 else {
            throw CardanoCoreError.deserializeError(
                "ProtocolParams: expected list of 17+ elements, got \(primitive)")
        }
        // Ranges as the ledger's ShelleyPParams hold them: Coin (Word64) fees
        // and deposits, Word32 sizes, a Word16 header size and nOpt, an
        // EpochInterval (Word32) eMax.
        minFeeA            = try f[0].integer("ProtocolParams minFeeA", as: Coin.self)
        minFeeB            = try f[1].integer("ProtocolParams minFeeB", as: Coin.self)
        maxBlockBodySize   = try f[2].integer("ProtocolParams maxBlockBodySize", as: UInt32.self)
        maxTxSize          = try f[3].integer("ProtocolParams maxTxSize", as: UInt32.self)
        maxBlockHeaderSize = try f[4].integer("ProtocolParams maxBlockHeaderSize", as: UInt16.self)
        keyDeposit         = try ShelleyGenesis.readUInt2(f[5], label: "keyDeposit")
        poolDeposit        = try ShelleyGenesis.readUInt2(f[6], label: "poolDeposit")
        eMax               = try f[7].integer("ProtocolParams eMax", as: EpochInterval.self)
        nOpt               = try f[8].integer("ProtocolParams nOpt", as: UInt16.self)
        // a0 is a NonNegativeInterval; rho, tau and d are UnitIntervals.
        a0                 = try ShelleyGenesis.readFraction2(f[9], label: "a0")
        rho                = try ShelleyGenesis.readFraction2(f[10], label: "rho", atMostOne: true)
        tau                = try ShelleyGenesis.readFraction2(f[11], label: "tau", atMostOne: true)
        decentralisationParam = try ShelleyGenesis.readFraction2(
            f[12], label: "decentralisationParam", atMostOne: true)
        extraEntropy       = Self.readExtraEntropy(f[13])

        // ShelleyGenesis CBOR may encode protocolVersion either as a [major, minor]
        // sublist (17-field layout) or as two flat uints (18-field layout).
        let trailingOffset: Int
        if case .list = f[14] {
            protocolVersion = try Self.readProtocolVersion(f[14])
            trailingOffset = 15
        } else {
            guard f.count >= 18 else {
                throw CardanoCoreError.deserializeError(
                    "ProtocolParams: flat protocolVersion layout requires 18+ elements, got \(f.count)")
            }
            let major = try f[14].integer("ProtocolParams protocolVersion.major", as: UInt32.self)
            let minor = try f[15].integer("ProtocolParams protocolVersion.minor", as: UInt32.self)
            protocolVersion = ProtocolVersion(minor: minor, major: major)
            trailingOffset = 16
        }
        minUTxOValue = try ShelleyGenesis.readUInt2(f[trailingOffset], label: "minUTxOValue")
        minPoolCost = try ShelleyGenesis.readUInt2(f[trailingOffset + 1], label: "minPoolCost")
    }

    public func toPrimitive() throws -> Primitive {
        let extraEntropyPrim: Primitive = extraEntropy.tag == "NeutralNonce"
            ? .list([.uint(0)])
            : .list([.uint(1)])
        let protocolVersionPrim: Primitive = .list([
            .integer(protocolVersion.major),
            .integer(protocolVersion.minor)
        ])
        var elements: [Primitive] = []
        elements.append(.integer(minFeeA))
        elements.append(.integer(minFeeB))
        elements.append(.integer(maxBlockBodySize))
        elements.append(.integer(maxTxSize))
        elements.append(.integer(maxBlockHeaderSize))
        elements.append(.integer(keyDeposit))
        elements.append(.integer(poolDeposit))
        elements.append(.integer(eMax))
        elements.append(.integer(nOpt))
        elements.append(try ShelleyGenesis.fractionPrimitive2(a0, label: "a0"))
        elements.append(try ShelleyGenesis.fractionPrimitive2(rho, label: "rho"))
        elements.append(try ShelleyGenesis.fractionPrimitive2(tau, label: "tau"))
        elements.append(try ShelleyGenesis.fractionPrimitive2(decentralisationParam, label: "decentralisationParam"))
        elements.append(extraEntropyPrim)
        elements.append(protocolVersionPrim)
        elements.append(.uint(minUTxOValue))
        elements.append(.uint(minPoolCost))
        return .list(elements)
    }

    /// Throws when a rational is outside its ledger type's range: `a0` a
    /// `NonNegativeInterval`; `rho`, `tau` and `d` `UnitInterval`s.
    func checkRationalRanges() throws {
        for (value, what, atMostOne) in [(a0, "a0", false), (rho, "rho", true), (tau, "tau", true),
                                          (decentralisationParam, "decentralisationParam", true)]
        where !value.isFinite || value < 0 || (atMostOne && value > 1) {
            throw CardanoCoreError.deserializeError("ProtocolParams \(what): \(value) is out of range")
        }
    }

    private static func readExtraEntropy(_ p: Primitive) -> ExtraEntropy {
        if case .list(let items) = p, items.first == .uint(0) {
            return ExtraEntropy(tag: "NeutralNonce")
        }
        return ExtraEntropy(tag: "Nonce")
    }

    private static func readProtocolVersion(_ p: Primitive) throws -> ProtocolVersion {
        guard case .list(let items) = p, items.count >= 2 else {
            throw CardanoCoreError.deserializeError("ProtocolParams: expected [major, minor] for protocolVersion")
        }
        let major = try items[0].integer("ProtocolParams protocolVersion.major", as: UInt32.self)
        let minor = try items[1].integer("ProtocolParams protocolVersion.minor", as: UInt32.self)
        return ProtocolVersion(minor: minor, major: major)
    }
}

// Internal helpers accessible to ProtocolParams (same module)
extension ShelleyGenesis {
    static func readUInt2(_ p: Primitive, label: String) throws -> UInt64 {
        try p.integer("ShelleyGenesis \(label)", as: UInt64.self)
    }

    /// A non-negative rational, as a tag-30 rational, a `[num, den]` pair or a
    /// float; at most one when `atMostOne`.
    static func readFraction2(_ p: Primitive, label: String, atMostOne: Bool = false) throws -> Double {
        let value: Double
        switch p {
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis: malformed tag-30 for \(label)")
            }
            value = try fractionPairToDouble(arr[0], arr[1], label: label)
        case .unitInterval(let ui):
            guard ui.denominator > 0 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis: zero denominator for \(label)")
            }
            value = Double(ui.numerator) / Double(ui.denominator)
        case .list(let arr) where arr.count == 2:
            value = try fractionPairToDouble(arr[0], arr[1], label: label)
        case .float(let f):
            guard f.isFinite, f >= 0 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis: \(label) \(f) is not a non-negative number")
            }
            value = f
        default:
            throw CardanoCoreError.deserializeError("ShelleyGenesis: expected tag-30 rational for \(label), got \(p)")
        }
        if atMostOne && value > 1 {
            throw CardanoCoreError.deserializeError("ShelleyGenesis: \(label) \(value) is above one")
        }
        return value
    }

    private static func fractionPairToDouble(_ num: Primitive, _ den: Primitive, label: String) throws -> Double {
        let n = try num.integer("ShelleyGenesis \(label) numerator", as: UInt64.self)
        let d = try den.integer("ShelleyGenesis \(label) denominator", as: UInt64.self)
        guard d > 0 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis: zero denominator for \(label)")
        }
        return Double(n) / Double(d)
    }

    /// `d` as a tag-30 rational over 10^7.
    ///
    /// - Throws: When `d` is negative, not finite, or too large to write.
    static func fractionPrimitive2(_ d: Double, label: String) throws -> Primitive {
        let precision = 10_000_000
        guard d.isFinite, d >= 0,
            let numerator = Int(exactly: (d * Double(precision)).rounded(.towardZero))
        else {
            throw CardanoCoreError.valueError("ShelleyGenesis: \(label) \(d) cannot be written as a rational")
        }
        let g = gcd2(numerator, precision)
        let tag = CBORTag(tag: 30, value: .list([.integer(numerator / g), .integer(precision / g)]))
        return .cborTag(tag)
    }

    private static func gcd2(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd2(b, a % b) }
}

// MARK: - Sendable
extension ShelleyGenesis: Sendable {}
extension ProtocolParams: Sendable {}
extension ProtocolParams.ProtocolVersion: Sendable {}
extension ProtocolParams.ExtraEntropy: Sendable {}
extension GenDelegation: Sendable {}
