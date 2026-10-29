import Foundation
@preconcurrency import BigInt

/// The Byron genesis file: the ledger's `GenesisData` (cardano-ledger
/// byron, `Cardano.Chain.Genesis.Data`) as the node reads it from canonical
/// JSON. Each field has the width of its ledger type; a value outside it is
/// refused, as the node refuses it.
///
/// Canonical JSON writes `Word64`, `Natural` and `Integer` values as strings
/// of digits and smaller numbers as JSON numbers; both are read and written
/// the way the node writes them.
public struct ByronGenesis: JSONLoadable {
    /// AVVM balances: `Lovelace` (a `Word64`, at most 45 × 10^15), written as
    /// strings.
    public let avvmDistr: [String: Coin]
    /// The Byron protocol parameters, `blockVersionData` for compatibility
    /// with the mainnet genesis block.
    public let blockVersionData: BlockVersionData
    /// FTS seed value, a legacy field the ledger no longer reads.
    public let ftsSeed: String?
    /// Protocol constants
    public let protocolConsts: ProtocolConsts
    /// Genesis start time, POSIX seconds (the ledger's `UTCTime`).
    public let startTime: Int64
    /// Boot stakeholders and their weights: `Map KeyHash Word16`.
    public let bootStakeholders: [String: UInt16]
    /// Heavy delegation certificates
    public let heavyDelegation: [String: HeavyDelegation]
    /// Non-AVVM balances: `Lovelace`, written as strings.
    public let nonAvvmBalances: [String: Coin]
    /// VSS certificates, a legacy field the ledger no longer reads.
    public let vssCerts: [String: VSSCert]?

    public init(
        avvmDistr: [String: Coin],
        blockVersionData: BlockVersionData,
        ftsSeed: String?,
        protocolConsts: ProtocolConsts,
        startTime: Int64,
        bootStakeholders: [String: UInt16],
        heavyDelegation: [String: HeavyDelegation],
        nonAvvmBalances: [String: Coin],
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

    /// The most lovelace there can be: `maxLovelaceVal`, 45 × 10^15.
    public static let maxLovelace: Coin = 45_000_000_000_000_000
}

// MARK: - LovelacePortion

/// The ledger's `LovelacePortion`: a fraction `numerator / 10^15` with the
/// numerator a `Word64` in `0 ... 10^15`. The genesis file writes the
/// numerator alone, as a string; it is held exactly here.
public struct LovelacePortion: Codable, Equatable, Hashable, Sendable {
    /// `lovelacePortionDenominator`, 10^15.
    public static let denominator: UInt64 = 1_000_000_000_000_000

    public let numerator: UInt64

    /// - Throws: When `numerator` is above 10^15.
    public init(numerator: UInt64) throws {
        guard numerator <= Self.denominator else {
            throw CardanoCoreError.valueError(
                "LovelacePortion: \(numerator) is not in 0 ... \(Self.denominator)")
        }
        self.numerator = numerator
    }

    /// The fraction `numerator / 10^15` in lowest terms.
    public var rational: (numerator: UInt64, denominator: UInt64) {
        var a = numerator, b = Self.denominator
        while b != 0 { (a, b) = (b, a % b) }
        return (numerator / a, Self.denominator / a)
    }

    public init(from decoder: Decoder) throws {
        let value = try byronInteger(from: decoder, "LovelacePortion")
        guard let numerator = UInt64(exactly: value) else {
            throw CardanoCoreError.deserializeError("LovelacePortion: \(value) is not a Word64")
        }
        try self.init(numerator: numerator)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(numerator))
    }

    init(primitive: Primitive?, _ what: String) throws {
        let value = try byronInteger(primitive, what)
        guard let numerator = UInt64(exactly: value) else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is not a Word64")
        }
        try self.init(numerator: numerator)
    }

    var primitive: Primitive { .string(String(numerator)) }
}

// MARK: - Nested types

/// The Byron `ProtocolParameters`, written in genesis as `blockVersionData`.
public struct BlockVersionData: Codable, Equatable, Hashable {
    /// `LovelacePortion`.
    public let heavyDelThd: LovelacePortion
    /// `Natural`; refused above `Word64`.
    public let maxBlockSize: UInt64
    /// `Natural`; refused above `Word64`.
    public let maxHeaderSize: UInt64
    /// `Natural`; refused above `Word64`.
    public let maxProposalSize: UInt64
    /// `Natural`; refused above `Word64`.
    public let maxTxSize: UInt64
    /// `LovelacePortion`.
    public let mpcThd: LovelacePortion
    /// `Word16`.
    public let scriptVersion: UInt16
    /// Milliseconds: a `Natural`, refused above `Word64`.
    public let slotDuration: UInt64
    public let softforkRule: SoftforkRule
    public let txFeePolicy: TxFeePolicy
    /// `EpochNumber`, a `Word64`.
    public let unlockStakeEpoch: EpochNumber
    /// The update proposal TTL: a `SlotNumber`, a `Word64`.
    public let updateImplicit: UInt64
    /// `LovelacePortion`.
    public let updateProposalThd: LovelacePortion
    /// `LovelacePortion`.
    public let updateVoteThd: LovelacePortion

    public init(
        heavyDelThd: LovelacePortion, maxBlockSize: UInt64, maxHeaderSize: UInt64, maxProposalSize: UInt64,
        maxTxSize: UInt64, mpcThd: LovelacePortion, scriptVersion: UInt16, slotDuration: UInt64,
        softforkRule: SoftforkRule, txFeePolicy: TxFeePolicy, unlockStakeEpoch: EpochNumber,
        updateImplicit: UInt64, updateProposalThd: LovelacePortion, updateVoteThd: LovelacePortion
    ) {
        self.heavyDelThd = heavyDelThd
        self.maxBlockSize = maxBlockSize
        self.maxHeaderSize = maxHeaderSize
        self.maxProposalSize = maxProposalSize
        self.maxTxSize = maxTxSize
        self.mpcThd = mpcThd
        self.scriptVersion = scriptVersion
        self.slotDuration = slotDuration
        self.softforkRule = softforkRule
        self.txFeePolicy = txFeePolicy
        self.unlockStakeEpoch = unlockStakeEpoch
        self.updateImplicit = updateImplicit
        self.updateProposalThd = updateProposalThd
        self.updateVoteThd = updateVoteThd
    }

    private enum CodingKeys: String, CodingKey {
        case heavyDelThd, maxBlockSize, maxHeaderSize, maxProposalSize, maxTxSize, mpcThd
        case scriptVersion, slotDuration, softforkRule, txFeePolicy, unlockStakeEpoch
        case updateImplicit, updateProposalThd, updateVoteThd
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            heavyDelThd: try c.decode(LovelacePortion.self, forKey: .heavyDelThd),
            maxBlockSize: try c.byronInteger(.maxBlockSize),
            maxHeaderSize: try c.byronInteger(.maxHeaderSize),
            maxProposalSize: try c.byronInteger(.maxProposalSize),
            maxTxSize: try c.byronInteger(.maxTxSize),
            mpcThd: try c.decode(LovelacePortion.self, forKey: .mpcThd),
            scriptVersion: try c.byronInteger(.scriptVersion),
            slotDuration: try c.byronInteger(.slotDuration),
            softforkRule: try c.decode(SoftforkRule.self, forKey: .softforkRule),
            txFeePolicy: try c.decode(TxFeePolicy.self, forKey: .txFeePolicy),
            unlockStakeEpoch: try c.byronInteger(.unlockStakeEpoch),
            updateImplicit: try c.byronInteger(.updateImplicit),
            updateProposalThd: try c.decode(LovelacePortion.self, forKey: .updateProposalThd),
            updateVoteThd: try c.decode(LovelacePortion.self, forKey: .updateVoteThd)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(heavyDelThd, forKey: .heavyDelThd)
        try c.encode(String(maxBlockSize), forKey: .maxBlockSize)
        try c.encode(String(maxHeaderSize), forKey: .maxHeaderSize)
        try c.encode(String(maxProposalSize), forKey: .maxProposalSize)
        try c.encode(String(maxTxSize), forKey: .maxTxSize)
        try c.encode(mpcThd, forKey: .mpcThd)
        // A Word16 is a canonical JSON number.
        try c.encode(scriptVersion, forKey: .scriptVersion)
        try c.encode(String(slotDuration), forKey: .slotDuration)
        try c.encode(softforkRule, forKey: .softforkRule)
        try c.encode(txFeePolicy, forKey: .txFeePolicy)
        try c.encode(String(unlockStakeEpoch), forKey: .unlockStakeEpoch)
        try c.encode(String(updateImplicit), forKey: .updateImplicit)
        try c.encode(updateProposalThd, forKey: .updateProposalThd)
        try c.encode(updateVoteThd, forKey: .updateVoteThd)
    }
}

/// The Byron `SoftforkRule`: three `LovelacePortion`s.
public struct SoftforkRule: Codable, Equatable, Hashable {
    public let initThd: LovelacePortion
    public let minThd: LovelacePortion
    public let thdDecrement: LovelacePortion

    public init(initThd: LovelacePortion, minThd: LovelacePortion, thdDecrement: LovelacePortion) {
        self.initThd = initThd
        self.minThd = minThd
        self.thdDecrement = thdDecrement
    }
}

/// The Byron `TxFeePolicy`, `TxSizeLinear summand multiplier`: a fee of
/// `summand + multiplier × size` for a transaction of `size` bytes.
///
/// The genesis file writes both scaled by 10^9, for compatibility with the
/// `Nano` coefficients of old: the ledger reads the summand as
/// `json div 10^9` lovelace and the multiplier as the exact rational
/// `json / 10^9`.
public struct TxFeePolicy: Codable, Equatable, Hashable {
    /// The ledger's scale on both coefficients, 10^9.
    public static let scale: UInt64 = 1_000_000_000

    /// `Lovelace`: at most 45 × 10^15.
    public let summand: Coin
    /// The multiplier in units of 10^-9 lovelace per byte, as the file writes
    /// it; the ledger's `Rational` is exactly `multiplier / 10^9`.
    public let multiplier: UInt64

    /// - Throws: When `summand` is above 45 × 10^15 lovelace.
    public init(summand: Coin, multiplier: UInt64) throws {
        guard summand <= ByronGenesis.maxLovelace else {
            throw CardanoCoreError.valueError("TxFeePolicy summand: \(summand) is above the lovelace supply")
        }
        self.summand = summand
        self.multiplier = multiplier
    }

    /// The multiplier as the ledger's exact `Rational`, in lowest terms.
    public var multiplierRational: (numerator: UInt64, denominator: UInt64) {
        var a = multiplier, b = Self.scale
        while b != 0 { (a, b) = (b, a % b) }
        return (multiplier / a, Self.scale / a)
    }

    private enum CodingKeys: String, CodingKey { case multiplier, summand }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            scaledSummand: try byronInteger(from: c.superDecoder(forKey: .summand), "TxFeePolicy summand"),
            scaledMultiplier: try byronInteger(from: c.superDecoder(forKey: .multiplier), "TxFeePolicy multiplier"))
    }

    /// From the values as the file writes them, read as the ledger reads
    /// them (`div` for the summand, which floors).
    init(scaledSummand: BigInt, scaledMultiplier: BigInt) throws {
        let scale = BigInt(Self.scale)
        let (quotient, remainder) = scaledSummand.quotientAndRemainder(dividingBy: scale)
        let floored = remainder < 0 ? quotient - 1 : quotient
        guard floored >= 0, let summand = Coin(exactly: floored), summand <= ByronGenesis.maxLovelace else {
            throw CardanoCoreError.deserializeError(
                "TxFeePolicy summand: \(scaledSummand) / 10^9 is not a lovelace amount")
        }
        guard let multiplier = UInt64(exactly: scaledMultiplier) else {
            throw CardanoCoreError.deserializeError(
                "TxFeePolicy multiplier: \(scaledMultiplier) is not a Word64 count of 10^-9 lovelace")
        }
        try self.init(summand: summand, multiplier: multiplier)
    }

    /// The summand as the file writes it, scaled by 10^9.
    var scaledSummand: String { (BigUInt(summand) * BigUInt(Self.scale)).description }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scaledSummand, forKey: .summand)
        try c.encode(String(multiplier), forKey: .multiplier)
    }
}

/// Protocol constants
public struct ProtocolConsts: Codable, Equatable, Hashable {
    /// `BlockCount`, a `Word64`.
    public let k: UInt64
    /// `ProtocolMagicId`, a `Word32`.
    public let protocolMagic: UInt32
    /// Legacy `VssMaxTTL`, a `Word32`; the ledger no longer reads it.
    public let vssMaxTTL: UInt32?
    /// Legacy `VssMinTTL`, a `Word32`; the ledger no longer reads it.
    public let vssMinTTL: UInt32?

    public init(k: UInt64, protocolMagic: UInt32, vssMaxTTL: UInt32? = nil, vssMinTTL: UInt32? = nil) {
        self.k = k
        self.protocolMagic = protocolMagic
        self.vssMaxTTL = vssMaxTTL
        self.vssMinTTL = vssMinTTL
    }
}

/// Heavy delegation certificate
public struct HeavyDelegation: Codable, Equatable, Hashable {
    public let cert: String
    public let delegatePk: String
    public let issuerPk: String
    /// The certificate's epoch: an `EpochNumber`, a `Word64`.
    public let omega: EpochNumber

    public init(cert: String, delegatePk: String, issuerPk: String, omega: EpochNumber) {
        self.cert = cert
        self.delegatePk = delegatePk
        self.issuerPk = issuerPk
        self.omega = omega
    }
}

/// VSS certificate
public struct VSSCert: Codable, Equatable, Hashable {
    /// `EpochNumber`, a `Word64`.
    public let expiryEpoch: EpochNumber
    public let signature: String
    public let signingKey: String
    public let vssKey: String

    public init(expiryEpoch: EpochNumber, signature: String, signingKey: String, vssKey: String) {
        self.expiryEpoch = expiryEpoch
        self.signature = signature
        self.signingKey = signingKey
        self.vssKey = vssKey
    }
}

// MARK: - Canonical JSON integers

/// A canonical JSON integer: a string of decimal digits, which is how
/// canonical JSON writes `Word64`, `Natural` and `Integer`, or a JSON number.
fileprivate func byronInteger(from decoder: Decoder, _ what: String) throws -> BigInt {
    let c = try decoder.singleValueContainer()
    if let text = try? c.decode(String.self) {
        return try byronInteger(text: text, what)
    }
    if let value = try? c.decode(UInt64.self) { return BigInt(value) }
    if let value = try? c.decode(Int64.self) { return BigInt(value) }
    // A JSON number too large for 64 bits: exact only while a Decimal holds
    // every digit, so a long one is refused rather than rounded.
    let value = try c.decode(Decimal.self)
    var whole = Decimal(), copy = value
    NSDecimalRound(&whole, &copy, 0, .down)
    guard !value.isNaN, whole == value, value.significand.description.count < 38,
          let integer = BigInt(value.description) else {
        throw CardanoCoreError.deserializeError("\(what): \(value) is not an integer")
    }
    return integer
}

fileprivate func byronInteger(text: String, _ what: String) throws -> BigInt {
    let digits = text.hasPrefix("-") ? text.dropFirst() : Substring(text)
    guard !digits.isEmpty, digits.allSatisfy({ ("0"..."9").contains($0) }), let value = BigInt(text) else {
        throw CardanoCoreError.deserializeError("\(what): \"\(text)\" is not an integer")
    }
    return value
}

/// An integer held in a primitive: a string of digits or an integer case.
fileprivate func byronInteger(_ primitive: Primitive?, _ what: String) throws -> BigInt {
    guard let primitive else {
        throw CardanoCoreError.deserializeError("\(what): missing")
    }
    if case .string(let text) = primitive { return try byronInteger(text: text, what) }
    guard let value = primitive.integerValue else {
        throw CardanoCoreError.deserializeError("\(what): expected an integer, got \(primitive)")
    }
    return value
}

fileprivate func narrow<T: FixedWidthInteger>(_ value: BigInt, _ what: String) throws -> T {
    guard let narrowed = T(exactly: value) else {
        throw CardanoCoreError.deserializeError("\(what): \(value) is out of range for \(T.self)")
    }
    return narrowed
}

fileprivate func lovelace(_ value: BigInt, _ what: String) throws -> Coin {
    let coin: Coin = try narrow(value, what)
    guard coin <= ByronGenesis.maxLovelace else {
        throw CardanoCoreError.deserializeError("\(what): \(coin) is above the lovelace supply")
    }
    return coin
}

/// A decodable canonical JSON integer, for the values of a map.
fileprivate struct ByronJSONInteger: Decodable {
    let value: BigInt
    init(from decoder: Decoder) throws {
        value = try byronInteger(from: decoder, decoder.codingPath.map(\.stringValue).joined(separator: "."))
    }
}

extension KeyedDecodingContainer {
    fileprivate func byronInteger<T: FixedWidthInteger>(_ key: Key, as type: T.Type = T.self) throws -> T {
        let decoder = try superDecoder(forKey: key)
        let what = decoder.codingPath.map(\.stringValue).joined(separator: ".")
        return try narrow(SwiftCardanoCore.byronInteger(from: decoder, what), what)
    }

    fileprivate func byronIntegerIfPresent<T: FixedWidthInteger>(_ key: Key, as type: T.Type = T.self) throws -> T? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try byronInteger(key, as: type)
    }

    fileprivate func byronMap<T: FixedWidthInteger>(
        _ key: Key, _ convert: (BigInt, String) throws -> T
    ) throws -> [String: T] {
        let raw = try decode([String: ByronJSONInteger].self, forKey: key)
        var result: [String: T] = [:]
        for (k, v) in raw { result[k] = try convert(v.value, "\(key.stringValue).\(k)") }
        return result
    }
}

// MARK: - Codable for the nested types

extension ProtocolConsts {
    private enum CodingKeys: String, CodingKey { case k, protocolMagic, vssMaxTTL, vssMinTTL }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            k: try c.byronInteger(.k),
            protocolMagic: try c.byronInteger(.protocolMagic),
            vssMaxTTL: try c.byronIntegerIfPresent(.vssMaxTTL),
            vssMinTTL: try c.byronIntegerIfPresent(.vssMinTTL))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(k, forKey: .k)
        try c.encode(protocolMagic, forKey: .protocolMagic)
        try c.encodeIfPresent(vssMaxTTL, forKey: .vssMaxTTL)
        try c.encodeIfPresent(vssMinTTL, forKey: .vssMinTTL)
    }
}

extension HeavyDelegation {
    private enum CodingKeys: String, CodingKey { case cert, delegatePk, issuerPk, omega }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            cert: try c.decode(String.self, forKey: .cert),
            delegatePk: try c.decode(String.self, forKey: .delegatePk),
            issuerPk: try c.decode(String.self, forKey: .issuerPk),
            omega: try c.byronInteger(.omega))
    }
}

extension VSSCert {
    private enum CodingKeys: String, CodingKey { case expiryEpoch, signature, signingKey, vssKey }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            expiryEpoch: try c.byronInteger(.expiryEpoch),
            signature: try c.decode(String.self, forKey: .signature),
            signingKey: try c.decode(String.self, forKey: .signingKey),
            vssKey: try c.decode(String.self, forKey: .vssKey))
    }
}

// MARK: - CBOR
//
// There is no ledger CBOR form of the genesis file that this mirrors: the
// node reads the file's canonical JSON. This writes a CBOR map with the JSON
// field names and values, strings where the JSON has strings.

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
                avvmDistr:        try c.byronMap(.avvmDistr, lovelace),
                blockVersionData: try c.decode(BlockVersionData.self, forKey: .blockVersionData),
                ftsSeed:          try c.decodeIfPresent(String.self, forKey: .ftsSeed),
                protocolConsts:   try c.decode(ProtocolConsts.self, forKey: .protocolConsts),
                startTime:        try c.byronInteger(.startTime),
                bootStakeholders: try c.byronMap(.bootStakeholders, narrow),
                heavyDelegation:  try c.decode([String: HeavyDelegation].self, forKey: .heavyDelegation),
                nonAvvmBalances:  try c.byronMap(.nonAvvmBalances, lovelace),
                vssCerts:         try c.decodeIfPresent([String: VSSCert].self, forKey: .vssCerts)
            )
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(avvmDistr.mapValues { String($0) }, forKey: .avvmDistr)
            try c.encode(blockVersionData, forKey: .blockVersionData)
            try c.encodeIfPresent(ftsSeed, forKey: .ftsSeed)
            try c.encode(protocolConsts, forKey: .protocolConsts)
            try c.encode(startTime, forKey: .startTime)
            try c.encode(bootStakeholders, forKey: .bootStakeholders)
            try c.encode(heavyDelegation, forKey: .heavyDelegation)
            try c.encode(nonAvvmBalances.mapValues { String($0) }, forKey: .nonAvvmBalances)
            try c.encodeIfPresent(vssCerts, forKey: .vssCerts)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        let dict = try Self.toStringDictPublic(primitive, label: "ByronGenesis")
        avvmDistr = try Self.readMap(dict["avvmDistr"], label: "avvmDistr") {
            try lovelace(byronInteger($0, $1), $1)
        }
        blockVersionData = try BlockVersionData(from: dict["blockVersionData"] ?? .null)
        ftsSeed = try Self.optionalString(dict["ftsSeed"], label: "ftsSeed")
        protocolConsts = try ProtocolConsts(from: dict["protocolConsts"] ?? .null)
        startTime = try narrow(byronInteger(dict["startTime"], "ByronGenesis startTime"), "ByronGenesis startTime")
        bootStakeholders = try Self.readMap(dict["bootStakeholders"], label: "bootStakeholders") {
            try narrow(byronInteger($0, $1), $1)
        }
        heavyDelegation = try Self.readMap(dict["heavyDelegation"], label: "heavyDelegation") { p, _ in
            try HeavyDelegation(from: p)
        }
        nonAvvmBalances = try Self.readMap(dict["nonAvvmBalances"], label: "nonAvvmBalances") {
            try lovelace(byronInteger($0, $1), $1)
        }
        if let certs = dict["vssCerts"], certs != .null {
            vssCerts = try Self.readMap(certs, label: "vssCerts") { p, _ in try VSSCert(from: p) }
        } else {
            vssCerts = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        // A CBOR map with string keys, as the JSON file has them.
        var pairs: [(Primitive, Primitive)] = []
        pairs.append((.string("startTime"), .int(startTime)))
        if let seed = ftsSeed { pairs.append((.string("ftsSeed"), .string(seed))) }
        pairs.append((.string("protocolConsts"), try protocolConsts.toPrimitive()))
        pairs.append((.string("blockVersionData"), try blockVersionData.toPrimitive()))
        pairs.append((.string("bootStakeholders"), .dict(Dictionary(uniqueKeysWithValues:
            bootStakeholders.map { (.string($0.key), .uint(UInt64($0.value))) }))))
        pairs.append((.string("avvmDistr"), .dict(Dictionary(uniqueKeysWithValues:
            avvmDistr.map { (.string($0.key), .string(String($0.value))) }))))
        pairs.append((.string("nonAvvmBalances"), .dict(Dictionary(uniqueKeysWithValues:
            nonAvvmBalances.map { (.string($0.key), .string(String($0.value))) }))))
        pairs.append((.string("heavyDelegation"), .dict(Dictionary(uniqueKeysWithValues:
            try heavyDelegation.map { try (.string($0.key), $0.value.toPrimitive()) }))))
        if let vssCerts {
            pairs.append((.string("vssCerts"), .dict(Dictionary(uniqueKeysWithValues:
                try vssCerts.map { try (.string($0.key), $0.value.toPrimitive()) }))))
        }
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }

    // MARK: Helpers

    private static func optionalString(_ p: Primitive?, label: String) throws -> String? {
        switch p {
        case nil, .null?: return nil
        case .string(let s)?: return s
        default: throw CardanoCoreError.deserializeError("ByronGenesis \(label): expected a string")
        }
    }

    /// A string-keyed map, each value read with `read`. Absent is empty.
    private static func readMap<T>(
        _ p: Primitive?, label: String, _ read: (Primitive, String) throws -> T
    ) throws -> [String: T] {
        let pairs: [(Primitive, Primitive)]
        switch p {
        case nil, .null?: return [:]
        case .dict(let d)?: pairs = Array(d)
        case .orderedDict(let d)?: pairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("ByronGenesis: expected a map for \(label)")
        }
        var result: [String: T] = [:]
        for (k, v) in pairs {
            guard case .string(let key) = k else {
                throw CardanoCoreError.deserializeError("ByronGenesis \(label): expected string keys")
            }
            result[key] = try read(v, "ByronGenesis \(label).\(key)")
        }
        return result
    }
}

// MARK: - Nested type CBOR extensions

extension BlockVersionData {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "BlockVersionData")
        func int<T: FixedWidthInteger>(_ key: String) throws -> T {
            try narrow(byronInteger(dict[key], "BlockVersionData \(key)"), "BlockVersionData \(key)")
        }
        func portion(_ key: String) throws -> LovelacePortion {
            try LovelacePortion(primitive: dict[key], "BlockVersionData \(key)")
        }
        self.init(
            heavyDelThd: try portion("heavyDelThd"),
            maxBlockSize: try int("maxBlockSize"),
            maxHeaderSize: try int("maxHeaderSize"),
            maxProposalSize: try int("maxProposalSize"),
            maxTxSize: try int("maxTxSize"),
            mpcThd: try portion("mpcThd"),
            scriptVersion: try int("scriptVersion"),
            slotDuration: try int("slotDuration"),
            softforkRule: try SoftforkRule(from: dict["softforkRule"] ?? .null),
            txFeePolicy: try TxFeePolicy(from: dict["txFeePolicy"] ?? .null),
            unlockStakeEpoch: try int("unlockStakeEpoch"),
            updateImplicit: try int("updateImplicit"),
            updateProposalThd: try portion("updateProposalThd"),
            updateVoteThd: try portion("updateVoteThd"))
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("heavyDelThd"), heavyDelThd.primitive),
            (.string("maxBlockSize"), .string(String(maxBlockSize))),
            (.string("maxHeaderSize"), .string(String(maxHeaderSize))),
            (.string("maxProposalSize"), .string(String(maxProposalSize))),
            (.string("maxTxSize"), .string(String(maxTxSize))),
            (.string("mpcThd"), mpcThd.primitive),
            (.string("scriptVersion"), .uint(UInt64(scriptVersion))),
            (.string("slotDuration"), .string(String(slotDuration))),
            (.string("softforkRule"), try softforkRule.toPrimitive()),
            (.string("txFeePolicy"), try txFeePolicy.toPrimitive()),
            (.string("unlockStakeEpoch"), .string(String(unlockStakeEpoch))),
            (.string("updateImplicit"), .string(String(updateImplicit))),
            (.string("updateProposalThd"), updateProposalThd.primitive),
            (.string("updateVoteThd"), updateVoteThd.primitive)
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension SoftforkRule {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "SoftforkRule")
        initThd      = try LovelacePortion(primitive: dict["initThd"], "SoftforkRule initThd")
        minThd       = try LovelacePortion(primitive: dict["minThd"], "SoftforkRule minThd")
        thdDecrement = try LovelacePortion(primitive: dict["thdDecrement"], "SoftforkRule thdDecrement")
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("initThd"), initThd.primitive),
            (.string("minThd"), minThd.primitive),
            (.string("thdDecrement"), thdDecrement.primitive)
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension TxFeePolicy {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "TxFeePolicy")
        try self.init(
            scaledSummand: try byronInteger(dict["summand"], "TxFeePolicy summand"),
            scaledMultiplier: try byronInteger(dict["multiplier"], "TxFeePolicy multiplier"))
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("multiplier"), .string(String(multiplier))),
            (.string("summand"), .string(scaledSummand))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension ProtocolConsts {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "ProtocolConsts")
        func optional(_ key: String) throws -> UInt32? {
            guard let p = dict[key], p != .null else { return nil }
            return try narrow(byronInteger(p, "ProtocolConsts \(key)"), "ProtocolConsts \(key)")
        }
        self.init(
            k: try narrow(byronInteger(dict["k"], "ProtocolConsts k"), "ProtocolConsts k"),
            protocolMagic: try narrow(byronInteger(dict["protocolMagic"], "ProtocolConsts protocolMagic"),
                                      "ProtocolConsts protocolMagic"),
            vssMaxTTL: try optional("vssMaxTTL"),
            vssMinTTL: try optional("vssMinTTL"))
    }

    public func toPrimitive() throws -> Primitive {
        var pairs: [(Primitive, Primitive)] = [
            (.string("k"), .uint(k)),
            (.string("protocolMagic"), .uint(UInt64(protocolMagic)))
        ]
        if let max = vssMaxTTL { pairs.append((.string("vssMaxTTL"), .uint(UInt64(max)))) }
        if let min = vssMinTTL { pairs.append((.string("vssMinTTL"), .uint(UInt64(min)))) }
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension HeavyDelegation {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "HeavyDelegation")
        self.init(
            cert: try ByronGenesis.requiredString(dict["cert"], "HeavyDelegation cert"),
            delegatePk: try ByronGenesis.requiredString(dict["delegatePk"], "HeavyDelegation delegatePk"),
            issuerPk: try ByronGenesis.requiredString(dict["issuerPk"], "HeavyDelegation issuerPk"),
            omega: try narrow(byronInteger(dict["omega"], "HeavyDelegation omega"), "HeavyDelegation omega"))
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("cert"), .string(cert)),
            (.string("delegatePk"), .string(delegatePk)),
            (.string("issuerPk"), .string(issuerPk)),
            (.string("omega"), .uint(omega))
        ]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

extension VSSCert {
    public init(from primitive: Primitive) throws {
        let dict = try ByronGenesis.toStringDictPublic(primitive, label: "VSSCert")
        self.init(
            expiryEpoch: try narrow(byronInteger(dict["expiryEpoch"], "VSSCert expiryEpoch"), "VSSCert expiryEpoch"),
            signature: try ByronGenesis.requiredString(dict["signature"], "VSSCert signature"),
            signingKey: try ByronGenesis.requiredString(dict["signingKey"], "VSSCert signingKey"),
            vssKey: try ByronGenesis.requiredString(dict["vssKey"], "VSSCert vssKey"))
    }

    public func toPrimitive() throws -> Primitive {
        let pairs: [(Primitive, Primitive)] = [
            (.string("expiryEpoch"), .uint(expiryEpoch)),
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
        let pairs: [(Primitive, Primitive)]
        switch p {
        case .dict(let d): pairs = Array(d)
        case .orderedDict(let d): pairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("\(label): expected string-keyed map")
        }
        var result: [String: Primitive] = [:]
        for (k, v) in pairs { if case .string(let s) = k { result[s] = v } }
        return result
    }

    static func requiredString(_ p: Primitive?, _ what: String) throws -> String {
        guard let p, case .string(let s) = p else {
            throw CardanoCoreError.deserializeError("\(what): expected a string")
        }
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
