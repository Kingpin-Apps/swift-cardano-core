import Foundation
import OrderedCollections
@preconcurrency import BigInt

/// The ledger's `ShelleyGenesis` (cardano-ledger, `Cardano.Ledger.Shelley.Genesis`).
/// Each field has the type of its ledger counterpart: integers their widths,
/// rationals exact `BoundedRatio Word64` values.
public struct ShelleyGenesis: JSONLoadable {
    /// `PositiveUnitInterval`: in `1/10^19 ... 1`.
    public let activeSlotsCoeff: UnitInterval
    public let protocolParams: ProtocolParams
    /// `Map (KeyHash GenesisRole) GenDelegPair`, keyed by the hex key hash.
    public let genDelegs: [String: GenDelegation]
    /// `Word64`.
    public let updateQuorum: UInt64
    /// `Network`: `"Mainnet"` or `"Testnet"`.
    public let networkId: String
    /// `ListMap Addr Coin`: each hex address's balance, a `Coin` (`Word64`),
    /// in the ledger's order.
    public let initialFunds: OrderedDictionary<String, Coin>
    /// `Word64`.
    public let maxLovelaceSupply: UInt64
    /// `Word32`.
    public let networkMagic: UInt32
    /// `EpochSize`, a `Word64`.
    public let epochLength: UInt64
    /// `UTCTime`, as the ledger writes it in JSON: `2017-09-23T21:44:51Z`.
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
    /// `ShelleyGenesisStaking`: pools to register and stake to delegate.
    public let staking: ShelleyGenesisStaking
    /// `StrictMaybe ShelleyExtraConfig`.
    public let extraConfig: ShelleyExtraConfig?

    public init(
        activeSlotsCoeff: UnitInterval,
        protocolParams: ProtocolParams,
        genDelegs: [String: GenDelegation],
        updateQuorum: UInt64,
        networkId: String,
        initialFunds: OrderedDictionary<String, Coin>,
        maxLovelaceSupply: UInt64,
        networkMagic: UInt32,
        epochLength: UInt64,
        systemStart: String,
        slotsPerKESPeriod: UInt64,
        slotLength: Decimal,
        maxKESEvolutions: UInt64,
        securityParam: UInt64,
        staking: ShelleyGenesisStaking = ShelleyGenesisStaking(),
        extraConfig: ShelleyExtraConfig? = nil
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
        self.staking = staking
        self.extraConfig = extraConfig
    }

    /// ``systemStart`` as a `Date`, or `nil` when it is not a valid `UTCTime`.
    /// A `Date` holds sub-microsecond fractions only approximately.
    public var systemStartDate: Date? {
        guard let time = try? ShelleyUTCTime(iso: systemStart) else { return nil }
        return time.date
    }
}

/// The ledger's `ShelleyPParams`, as Shelley genesis holds them. Each field
/// has the type of its ledger counterpart.
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

    /// `Nonce`: `NeutralNonce`, or a `Nonce` holding a 32-byte hash.
    public struct ExtraEntropy: Codable, Equatable, Hashable {
        /// `"NeutralNonce"` or `"Nonce"`.
        public let tag: String
        /// The nonce's hex hash when ``tag`` is `"Nonce"`.
        public let contents: String?

        public static let neutral = ExtraEntropy(tag: "NeutralNonce", contents: nil)

        public init(tag: String, contents: String? = nil) {
            self.tag = tag
            self.contents = contents
        }

        private enum CodingKeys: String, CodingKey { case tag, contents }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let tag = try c.decode(String.self, forKey: .tag)
            switch tag {
            case "NeutralNonce":
                self.init(tag: tag)
            case "Nonce":
                let hash = try c.decode(String.self, forKey: .contents)
                guard let bytes = shelleyHexData(hash), bytes.count == 32 else {
                    throw CardanoCoreError.deserializeError("ExtraEntropy: \(hash) is not a 32-byte hex hash")
                }
                self.init(tag: tag, contents: bytes.toHex)
            default:
                throw CardanoCoreError.deserializeError("ExtraEntropy: unknown tag \(tag)")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(tag, forKey: .tag)
            if tag == "Nonce" { try c.encodeIfPresent(contents, forKey: .contents) }
        }

        /// The entropy of `nonce`.
        public init(_ nonce: Nonce) {
            if let hash = nonce.hash {
                self.init(tag: "Nonce", contents: hash.toHex)
            } else {
                self = .neutral
            }
        }

        /// This entropy as a ``Nonce``.
        ///
        /// - Throws: When ``tag`` is neither `NeutralNonce` nor `Nonce`, or a
        ///   `Nonce` does not hold a 32-byte hex hash.
        public func nonce() throws -> Nonce {
            switch tag {
            case "NeutralNonce":
                return .neutral
            case "Nonce":
                guard let contents else {
                    throw CardanoCoreError.valueError("ExtraEntropy: a Nonce needs its hash")
                }
                return try Nonce(hash: try shelleyHexBytes(contents, Nonce.hashSize, "extraEntropy nonce"))
            default:
                throw CardanoCoreError.valueError("ExtraEntropy: unknown tag \(tag)")
            }
        }
    }

    public let protocolVersion: ProtocolVersion
    /// `UnitInterval`.
    public let decentralisationParam: UnitInterval
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
    /// `Coin`.
    public let minUTxOValue: Coin
    /// `Coin`.
    public let poolDeposit: Coin
    /// `Coin`.
    public let minPoolCost: Coin
    /// `Coin`.
    public let keyDeposit: Coin
    /// `Word16`.
    public let nOpt: UInt16
    /// `UnitInterval`.
    public let rho: UnitInterval
    /// `UnitInterval`.
    public let tau: UnitInterval
    /// `NonNegativeInterval`.
    public let a0: NonNegativeInterval

    public init(
        protocolVersion: ProtocolVersion, decentralisationParam: UnitInterval, eMax: EpochInterval,
        extraEntropy: ExtraEntropy, maxTxSize: UInt32, maxBlockBodySize: UInt32, maxBlockHeaderSize: UInt16,
        minFeeA: Coin, minFeeB: Coin, minUTxOValue: Coin, poolDeposit: Coin, minPoolCost: Coin,
        keyDeposit: Coin, nOpt: UInt16, rho: UnitInterval, tau: UnitInterval, a0: NonNegativeInterval
    ) {
        self.protocolVersion = protocolVersion
        self.decentralisationParam = decentralisationParam
        self.eMax = eMax
        self.extraEntropy = extraEntropy
        self.maxTxSize = maxTxSize
        self.maxBlockBodySize = maxBlockBodySize
        self.maxBlockHeaderSize = maxBlockHeaderSize
        self.minFeeA = minFeeA
        self.minFeeB = minFeeB
        self.minUTxOValue = minUTxOValue
        self.poolDeposit = poolDeposit
        self.minPoolCost = minPoolCost
        self.keyDeposit = keyDeposit
        self.nOpt = nOpt
        self.rho = rho
        self.tau = tau
        self.a0 = a0
    }

    private enum CodingKeys: String, CodingKey {
        case minFeeA, minFeeB, maxBlockBodySize, maxTxSize, maxBlockHeaderSize, keyDeposit, poolDeposit
        case eMax, nOpt, a0, rho, tau, decentralisationParam, extraEntropy, protocolVersion
        case minUTxOValue, minPoolCost
    }

    /// Reads the ledger's legacy Shelley parameters JSON: rationals exactly,
    /// `minUTxOValue` and `minPoolCost` zero when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            protocolVersion: try c.decode(ProtocolVersion.self, forKey: .protocolVersion),
            decentralisationParam: try c.decodeUnitInterval(forKey: .decentralisationParam),
            eMax: try c.decode(EpochInterval.self, forKey: .eMax),
            extraEntropy: try c.decode(ExtraEntropy.self, forKey: .extraEntropy),
            maxTxSize: try c.decode(UInt32.self, forKey: .maxTxSize),
            maxBlockBodySize: try c.decode(UInt32.self, forKey: .maxBlockBodySize),
            maxBlockHeaderSize: try c.decode(UInt16.self, forKey: .maxBlockHeaderSize),
            minFeeA: try c.decode(Coin.self, forKey: .minFeeA),
            minFeeB: try c.decode(Coin.self, forKey: .minFeeB),
            minUTxOValue: try c.decodeIfPresent(Coin.self, forKey: .minUTxOValue) ?? 0,
            poolDeposit: try c.decode(Coin.self, forKey: .poolDeposit),
            minPoolCost: try c.decodeIfPresent(Coin.self, forKey: .minPoolCost) ?? 0,
            keyDeposit: try c.decode(Coin.self, forKey: .keyDeposit),
            nOpt: try c.decode(UInt16.self, forKey: .nOpt),
            rho: try c.decodeUnitInterval(forKey: .rho),
            tau: try c.decodeUnitInterval(forKey: .tau),
            a0: try c.decodeNonNegativeInterval(forKey: .a0)
        )
    }

    /// Writes the ledger's legacy Shelley parameters JSON
    /// (`legacyToJSONPParams`), rationals as the ledger writes them.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(minFeeA, forKey: .minFeeA)
        try c.encode(minFeeB, forKey: .minFeeB)
        try c.encode(maxBlockBodySize, forKey: .maxBlockBodySize)
        try c.encode(maxTxSize, forKey: .maxTxSize)
        try c.encode(maxBlockHeaderSize, forKey: .maxBlockHeaderSize)
        try c.encode(keyDeposit, forKey: .keyDeposit)
        try c.encode(poolDeposit, forKey: .poolDeposit)
        try c.encode(eMax, forKey: .eMax)
        try c.encode(nOpt, forKey: .nOpt)
        try c.encodeLedgerRational(a0, forKey: .a0)
        try c.encodeLedgerRational(rho, forKey: .rho)
        try c.encodeLedgerRational(tau, forKey: .tau)
        try c.encodeLedgerRational(decentralisationParam, forKey: .decentralisationParam)
        try c.encode(extraEntropy, forKey: .extraEntropy)
        try c.encode(protocolVersion, forKey: .protocolVersion)
        try c.encode(minUTxOValue, forKey: .minUTxOValue)
        try c.encode(minPoolCost, forKey: .minPoolCost)
    }
}

/// `GenDelegPair`: a genesis delegate's key hash and VRF key hash, in hex.
public struct GenDelegation: Codable, Equatable, Hashable {
    public let delegate: String
    public let vrf: String

    public init(delegate: String, vrf: String) {
        self.delegate = delegate
        self.vrf = vrf
    }
}

/// `ShelleyGenesisStaking`: stake pools to register at genesis and the stake
/// delegated to them.
public struct ShelleyGenesisStaking: Codable, Equatable, Hashable, Sendable {
    /// `ListMap (KeyHash StakePool) (StakePoolParams ShelleyEra)`: each pool's
    /// parameters, kept as the CBOR the ledger writes for them
    /// (`StakePoolParams`, a 9-element list), keyed by the hex pool key hash.
    public let pools: OrderedDictionary<String, Primitive>
    /// `ListMap (KeyHash Staking) (KeyHash StakePool)`: each hex staking key
    /// hash and the hex pool key hash it delegates to.
    public let stake: OrderedDictionary<String, String>

    public init(pools: OrderedDictionary<String, Primitive> = [:], stake: OrderedDictionary<String, String> = [:]) {
        self.pools = pools
        self.stake = stake
    }

    private enum CodingKeys: String, CodingKey { case pools, stake }

    /// Reads `{"pools": {...}, "stake": {...}}`.
    ///
    /// - Throws: For a non-empty `pools`: pool parameters are only read from
    ///   CBOR.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let pools = try c.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .pools)
        guard pools.allKeys.isEmpty else {
            throw CardanoCoreError.deserializeError(
                "ShelleyGenesis staking.pools: pool parameters are only read from CBOR")
        }
        let stake = try shelleyJSONMap(c, .stake, String.self, "staking.stake")
        var checked = OrderedDictionary<String, String>()
        for (key, pool) in stake {
            checked[try shelleyHash(key, 28, "staking.stake key")] = try shelleyHash(pool, 28, "staking.stake pool")
        }
        self.init(pools: [:], stake: checked)
    }

    public func encode(to encoder: Encoder) throws {
        guard pools.isEmpty else {
            throw CardanoCoreError.valueError("ShelleyGenesis staking.pools: pool parameters are only written to CBOR")
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        _ = c.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .pools)
        var stakeContainer = c.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .stake)
        for (key, pool) in stake { try stakeContainer.encode(pool, forKey: ShelleyJSONKey(key)) }
    }
}

/// `InjectionData k v`: data injected into genesis.
public enum ShelleyGenesisInjection<Value: Hashable & Sendable>: Hashable, Sendable {
    /// `NoInjection`.
    case none
    /// `InjectionFromFile`: a file's path segments and its Blake2b-256 hex hash.
    case file(path: [String], hash: String)
    /// `EmbeddedInjection`: the data itself, in order.
    case embedded(OrderedDictionary<String, Value>)
}

/// `ShelleyExtraConfig`: genesis data injected for streaming.
public struct ShelleyExtraConfig: Codable, Equatable, Hashable, Sendable {
    /// `InjectionData Addr Coin`.
    public let initialFunds: ShelleyGenesisInjection<Coin>
    /// `InjectionData (KeyHash StakePool) (StakePoolParams ShelleyEra)`: pool
    /// parameters kept as their CBOR.
    public let stakePools: ShelleyGenesisInjection<Primitive>
    /// `InjectionData (KeyHash Staking) (KeyHash StakePool)`.
    public let stakeCredentials: ShelleyGenesisInjection<String>

    public init(
        initialFunds: ShelleyGenesisInjection<Coin> = .none,
        stakePools: ShelleyGenesisInjection<Primitive> = .none,
        stakeCredentials: ShelleyGenesisInjection<String> = .none
    ) {
        self.initialFunds = initialFunds
        self.stakePools = stakePools
        self.stakeCredentials = stakeCredentials
    }

    private enum CodingKeys: String, CodingKey { case initialFunds, stakePools, stakeCredentials }
    private enum InjectionKeys: String, CodingKey { case file, hash, data }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func injection<V: Decodable>(
            _ key: CodingKeys, _ type: V.Type, _ check: (String, V) throws -> (String, V)
        ) throws -> ShelleyGenesisInjection<V> {
            guard c.contains(key) else { return .none }
            let o = try c.nestedContainer(keyedBy: InjectionKeys.self, forKey: key)
            switch (o.contains(.file), o.contains(.data)) {
            case (true, false):
                let path = try o.decode([String].self, forKey: .file)
                let hash = try shelleyHash(try o.decode(String.self, forKey: .hash), 32, "\(key.rawValue).hash")
                return .file(path: path, hash: hash)
            case (false, true):
                var data = OrderedDictionary<String, V>()
                for (k, v) in try shelleyJSONMap(o, .data, V.self, "\(key.rawValue).data") {
                    let (k2, v2) = try check(k, v)
                    data[k2] = v2
                }
                return .embedded(data)
            case (false, false):
                return .none
            case (true, true):
                throw CardanoCoreError.deserializeError(
                    "ShelleyExtraConfig \(key.rawValue): cannot specify both \"file\" and \"data\"")
            }
        }
        let funds = try injection(.initialFunds, Coin.self) { (try shelleyAddress($0), $1) }
        let creds = try injection(.stakeCredentials, String.self) {
            (try shelleyHash($0, 28, "stakeCredentials key"), try shelleyHash($1, 28, "stakeCredentials pool"))
        }
        let pools: ShelleyGenesisInjection<Primitive>
        if c.contains(.stakePools) {
            let o = try c.nestedContainer(keyedBy: InjectionKeys.self, forKey: .stakePools)
            if o.contains(.data) {
                let data = try o.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .data)
                guard data.allKeys.isEmpty else {
                    throw CardanoCoreError.deserializeError(
                        "ShelleyExtraConfig stakePools: pool parameters are only read from CBOR")
                }
                guard !o.contains(.file) else {
                    throw CardanoCoreError.deserializeError(
                        "ShelleyExtraConfig stakePools: cannot specify both \"file\" and \"data\"")
                }
                pools = .embedded([:])
            } else if o.contains(.file) {
                let hash = try shelleyHash(try o.decode(String.self, forKey: .hash), 32, "stakePools.hash")
                pools = .file(path: try o.decode([String].self, forKey: .file), hash: hash)
            } else {
                pools = .none
            }
        } else {
            pools = .none
        }
        self.init(initialFunds: funds, stakePools: pools, stakeCredentials: creds)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func write<V: Encodable>(_ value: ShelleyGenesisInjection<V>, _ key: CodingKeys) throws {
            var o = c.nestedContainer(keyedBy: InjectionKeys.self, forKey: key)
            switch value {
            case .none: break
            case .file(let path, let hash):
                try o.encode(path, forKey: .file)
                try o.encode(hash, forKey: .hash)
            case .embedded(let data):
                var d = o.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .data)
                for (k, v) in data { try d.encode(v, forKey: ShelleyJSONKey(k)) }
            }
        }
        try write(initialFunds, .initialFunds)
        switch stakePools {
        case .none:
            try write(ShelleyGenesisInjection<String>.none, .stakePools)
        case .file(let path, let hash):
            try write(ShelleyGenesisInjection<String>.file(path: path, hash: hash), .stakePools)
        case .embedded(let data):
            guard data.isEmpty else {
                throw CardanoCoreError.valueError(
                    "ShelleyExtraConfig stakePools: pool parameters are only written to CBOR")
            }
            try write(ShelleyGenesisInjection<String>.embedded([:]), .stakePools)
        }
        try write(stakeCredentials, .stakeCredentials)
    }
}

// MARK: - JSON

extension ShelleyGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case systemStart, networkMagic, networkId, activeSlotsCoeff, securityParam, epochLength
        case slotsPerKESPeriod, maxKESEvolutions, slotLength, updateQuorum, maxLovelaceSupply
        case protocolParams, genDelegs, initialFunds, staking, extraConfig
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let securityParam = try c.decode(UInt64.self, forKey: .securityParam)
            guard securityParam > 0 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis securityParam: must not be zero")
            }
            let networkId = try c.decode(String.self, forKey: .networkId)
            guard networkId == "Mainnet" || networkId == "Testnet" else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis networkId: \(networkId) is not a network")
            }
            var genDelegs: [String: GenDelegation] = [:]
            for (key, pair) in try shelleyJSONMap(c, .genDelegs, GenDelegation.self, "genDelegs") {
                genDelegs[try shelleyHash(key, 28, "genDelegs key")] = GenDelegation(
                    delegate: try shelleyHash(pair.delegate, 28, "genDelegs delegate"),
                    vrf: try shelleyHash(pair.vrf, 32, "genDelegs vrf"))
            }
            var initialFunds = OrderedDictionary<String, Coin>()
            for (address, coin) in try shelleyJSONMap(c, .initialFunds, Coin.self, "initialFunds") {
                initialFunds[try shelleyAddress(address)] = coin
            }
            self.init(
                activeSlotsCoeff:  try c.decodeUnitInterval(forKey: .activeSlotsCoeff, bounds: .positiveUnitInterval),
                protocolParams:    try c.decode(ProtocolParams.self, forKey: .protocolParams),
                genDelegs:         genDelegs,
                updateQuorum:      try c.decode(UInt64.self, forKey: .updateQuorum),
                networkId:         networkId,
                initialFunds:      initialFunds,
                maxLovelaceSupply: try c.decode(UInt64.self, forKey: .maxLovelaceSupply),
                networkMagic:      try c.decode(UInt32.self, forKey: .networkMagic),
                epochLength:       try c.decode(UInt64.self, forKey: .epochLength),
                systemStart:       try ShelleyUTCTime(iso: try c.decode(String.self, forKey: .systemStart)).iso,
                slotsPerKESPeriod: try c.decode(UInt64.self, forKey: .slotsPerKESPeriod),
                slotLength:        Self.truncatedToMicroseconds(try c.decode(Decimal.self, forKey: .slotLength)),
                maxKESEvolutions:  try c.decode(UInt64.self, forKey: .maxKESEvolutions),
                securityParam:     securityParam,
                staking:           try c.decodeIfPresent(ShelleyGenesisStaking.self, forKey: .staking)
                    ?? ShelleyGenesisStaking(),
                extraConfig:       try c.decodeIfPresent(ShelleyExtraConfig.self, forKey: .extraConfig)
            )
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    /// Writes the ledger's JSON (`ToKeyValuePairs ShelleyGenesis`).
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(systemStart, forKey: .systemStart)
            try c.encode(networkMagic, forKey: .networkMagic)
            try c.encode(networkId, forKey: .networkId)
            try c.encodeLedgerRational(activeSlotsCoeff, forKey: .activeSlotsCoeff)
            try c.encode(securityParam, forKey: .securityParam)
            try c.encode(epochLength, forKey: .epochLength)
            try c.encode(slotsPerKESPeriod, forKey: .slotsPerKESPeriod)
            try c.encode(maxKESEvolutions, forKey: .maxKESEvolutions)
            try c.encode(slotLength, forKey: .slotLength)
            try c.encode(updateQuorum, forKey: .updateQuorum)
            try c.encode(maxLovelaceSupply, forKey: .maxLovelaceSupply)
            try c.encode(protocolParams, forKey: .protocolParams)
            try c.encode(genDelegs, forKey: .genDelegs)
            var funds = c.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: .initialFunds)
            for (address, coin) in initialFunds { try funds.encode(coin, forKey: ShelleyJSONKey(address)) }
            try c.encode(staking, forKey: .staking)
            try c.encodeIfPresent(extraConfig, forKey: .extraConfig)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    // MARK: CBOR
    //
    // The ledger's `EncCBOR ShelleyGenesis`, written at the Shelley protocol
    // version (`toPlainEncoding shelleyProtVer`), is a 16-element list:
    //   [0] systemStart (UTCTime)  [1] networkMagic  [2] networkId (word8)
    //   [3] activeSlotsCoeff (untagged rational)  [4] securityParam
    //   [5] epochLength  [6] slotsPerKESPeriod  [7] maxKESEvolutions
    //   [8] slotLength (microseconds)  [9] updateQuorum  [10] maxLovelaceSupply
    //   [11] protocolParams  [12] genDelegs  [13] initialFunds  [14] staking
    //   [15] extraConfig (StrictMaybe)

    public init(from primitive: Primitive) throws {
        let f = try shelleyList(primitive, "ShelleyGenesis")
        guard f.count == 16 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis: expected 16 fields, got \(f.count)")
        }
        systemStart   = try ShelleyUTCTime(primitive: f[0]).iso
        networkMagic  = try f[1].integer("ShelleyGenesis networkMagic", as: UInt32.self)
        switch try f[2].integer("ShelleyGenesis networkId", as: UInt8.self) {
        case 0: networkId = "Testnet"
        case 1: networkId = "Mainnet"
        case let other:
            throw CardanoCoreError.deserializeError("ShelleyGenesis networkId: unknown network \(other)")
        }
        // `activeSlotsCoeffDecCBOR`: a rational without tag 30.
        activeSlotsCoeff = try UnitInterval.ledgerCBOR(
            f[3], bounds: .positiveUnitInterval, "ShelleyGenesis activeSlotsCoeff", tagged: false)
        securityParam = try f[4].integer("ShelleyGenesis securityParam", as: UInt64.self)
        guard securityParam > 0 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis securityParam: must not be zero")
        }
        epochLength       = try f[5].integer("ShelleyGenesis epochLength", as: UInt64.self)
        slotsPerKESPeriod = try f[6].integer("ShelleyGenesis slotsPerKESPeriod", as: UInt64.self)
        maxKESEvolutions  = try f[7].integer("ShelleyGenesis maxKESEvolutions", as: UInt64.self)
        slotLength        = try Self.readSlotLength(f[8])
        updateQuorum      = try f[9].integer("ShelleyGenesis updateQuorum", as: UInt64.self)
        maxLovelaceSupply = try f[10].integer("ShelleyGenesis maxLovelaceSupply", as: UInt64.self)
        protocolParams    = try ProtocolParams(from: f[11])
        var delegs: [String: GenDelegation] = [:]
        for (key, value) in try shelleyMapEntries(f[12], "ShelleyGenesis genDelegs", listMap: false) {
            let pair = try shelleyList(value, "ShelleyGenesis GenDelegPair")
            guard pair.count == 2 else {
                throw CardanoCoreError.deserializeError("ShelleyGenesis GenDelegPair: expected 2 fields")
            }
            // `Map.fromList`: a repeated key keeps its last value.
            delegs[try shelleyBytes(key, 28, "genDelegs key")] = GenDelegation(
                delegate: try shelleyBytes(pair[0], 28, "genDelegs delegate"),
                vrf: try shelleyBytes(pair[1], 32, "genDelegs vrf"))
        }
        genDelegs = delegs
        var funds = OrderedDictionary<String, Coin>()
        for (key, value) in try shelleyMapEntries(f[13], "ShelleyGenesis initialFunds", listMap: true) {
            funds[try shelleyBytes(key, nil, "initialFunds address")] =
                try value.integer("ShelleyGenesis initialFunds balance", as: Coin.self)
        }
        initialFunds = funds
        staking = try ShelleyGenesisStaking(from: f[14])
        let extra = try shelleyList(f[15], "ShelleyGenesis extraConfig")
        switch extra.count {
        case 0: extraConfig = nil
        case 1: extraConfig = try ShelleyExtraConfig(from: extra[0])
        default:
            throw CardanoCoreError.deserializeError("ShelleyGenesis extraConfig: a StrictMaybe has at most 1 element")
        }
    }

    public func toPrimitive() throws -> Primitive {
        let network: UInt64
        switch networkId {
        case "Testnet": network = 0
        case "Mainnet": network = 1
        default: throw CardanoCoreError.valueError("ShelleyGenesis networkId: \(networkId) is not a network")
        }
        try LedgerRational.check(activeSlotsCoeff.numerator, activeSlotsCoeff.denominator,
                                 .positiveUnitInterval, "ShelleyGenesis activeSlotsCoeff")
        guard securityParam > 0 else {
            throw CardanoCoreError.valueError("ShelleyGenesis securityParam: must not be zero")
        }
        // `encodeMap`: ascending key order; more than 23 entries indefinite.
        var delegs: [(Data, Primitive)] = []
        for (key, pair) in genDelegs {
            delegs.append((try shelleyHexBytes(key, 28, "genDelegs key"), .list([
                .bytes(try shelleyHexBytes(pair.delegate, 28, "genDelegs delegate")),
                .bytes(try shelleyHexBytes(pair.vrf, 32, "genDelegs vrf")),
            ])))
        }
        delegs.sort { $0.0.lexicographicallyPrecedes($1.0) }
        let delegEntries = OrderedDictionary(uniqueKeysWithValues: delegs.map { (Primitive.bytes($0.0), $0.1) })
        var funds = OrderedDictionary<Primitive, Primitive>()
        for (address, coin) in initialFunds {
            funds[.bytes(try shelleyHexBytes(address, nil, "initialFunds address"))] = .integer(coin)
        }
        return .list([
            try ShelleyUTCTime(iso: systemStart).primitive,
            .integer(networkMagic),
            .uint(network),
            activeSlotsCoeff.ledgerPrimitive(tagged: false),
            .integer(securityParam),
            .integer(epochLength),
            .integer(slotsPerKESPeriod),
            .integer(maxKESEvolutions),
            try Self.slotLengthPrimitive(slotLength),
            .integer(updateQuorum),
            .integer(maxLovelaceSupply),
            try protocolParams.toPrimitive(),
            delegEntries.count <= 23 ? .orderedDict(delegEntries) : .indefiniteDictionary(delegEntries),
            .orderedDict(funds),
            try staking.toPrimitive(),
            .list(try extraConfig.map { [try $0.toPrimitive()] } ?? []),
        ])
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
}

// MARK: - ProtocolParams CBOR
//
// `PParams ShelleyEra` encodes as a 17-element list (`eraPParams`):
//   [0] minFeeA  [1] minFeeB  [2] maxBlockBodySize  [3] maxTxSize  [4] maxBlockHeaderSize
//   [5] keyDeposit  [6] poolDeposit  [7] eMax  [8] nOpt
//   [9] a0  [10] rho  [11] tau  [12] decentralisationParam (each #6.30)
//   [13] extraEntropy ([0] or [1, hash])  [14] protocolVersion ([major, minor])
//   [15] minUTxOValue  [16] minPoolCost

extension ProtocolParams {
    public init(from primitive: Primitive) throws {
        let f = try shelleyList(primitive, "ProtocolParams")
        guard f.count == 17 else {
            throw CardanoCoreError.deserializeError("ProtocolParams: expected 17 fields, got \(f.count)")
        }
        minFeeA            = try f[0].integer("ProtocolParams minFeeA", as: Coin.self)
        minFeeB            = try f[1].integer("ProtocolParams minFeeB", as: Coin.self)
        maxBlockBodySize   = try f[2].integer("ProtocolParams maxBlockBodySize", as: UInt32.self)
        maxTxSize          = try f[3].integer("ProtocolParams maxTxSize", as: UInt32.self)
        maxBlockHeaderSize = try f[4].integer("ProtocolParams maxBlockHeaderSize", as: UInt16.self)
        keyDeposit         = try f[5].integer("ProtocolParams keyDeposit", as: Coin.self)
        poolDeposit        = try f[6].integer("ProtocolParams poolDeposit", as: Coin.self)
        eMax               = try f[7].integer("ProtocolParams eMax", as: EpochInterval.self)
        nOpt               = try f[8].integer("ProtocolParams nOpt", as: UInt16.self)
        a0                 = try NonNegativeInterval.ledgerCBOR(f[9], "ProtocolParams a0")
        rho                = try UnitInterval.ledgerCBOR(f[10], "ProtocolParams rho")
        tau                = try UnitInterval.ledgerCBOR(f[11], "ProtocolParams tau")
        decentralisationParam = try UnitInterval.ledgerCBOR(f[12], "ProtocolParams decentralisationParam")
        extraEntropy       = try Self.readExtraEntropy(f[13])
        let version = try shelleyList(f[14], "ProtocolParams protocolVersion")
        guard version.count == 2 else {
            throw CardanoCoreError.deserializeError("ProtocolParams protocolVersion: expected [major, minor]")
        }
        protocolVersion = ProtocolVersion(
            minor: try version[1].integer("ProtocolParams protocolVersion.minor", as: UInt32.self),
            major: try version[0].integer("ProtocolParams protocolVersion.major", as: UInt32.self))
        minUTxOValue = try f[15].integer("ProtocolParams minUTxOValue", as: Coin.self)
        minPoolCost  = try f[16].integer("ProtocolParams minPoolCost", as: Coin.self)
    }

    public func toPrimitive() throws -> Primitive {
        try LedgerRational.check(a0.numerator, a0.denominator, .nonNegativeInterval, "ProtocolParams a0")
        for (value, what) in [(rho, "rho"), (tau, "tau"), (decentralisationParam, "decentralisationParam")] {
            try LedgerRational.check(value.numerator, value.denominator, .unitInterval, "ProtocolParams \(what)")
        }
        return .list([
            .integer(minFeeA),
            .integer(minFeeB),
            .integer(maxBlockBodySize),
            .integer(maxTxSize),
            .integer(maxBlockHeaderSize),
            .integer(keyDeposit),
            .integer(poolDeposit),
            .integer(eMax),
            .integer(nOpt),
            a0.ledgerPrimitive(),
            rho.ledgerPrimitive(),
            tau.ledgerPrimitive(),
            decentralisationParam.ledgerPrimitive(),
            try Self.extraEntropyPrimitive(extraEntropy),
            .list([.integer(protocolVersion.major), .integer(protocolVersion.minor)]),
            .integer(minUTxOValue),
            .integer(minPoolCost),
        ])
    }

    /// `Nonce`: `[0]` for `NeutralNonce`, `[1, hash]` for a `Nonce`.
    private static func readExtraEntropy(_ p: Primitive) throws -> ExtraEntropy {
        do {
            return ExtraEntropy(try Nonce(from: p))
        } catch {
            throw CardanoCoreError.deserializeError("ProtocolParams extraEntropy: not a Nonce: \(p): \(error)")
        }
    }

    private static func extraEntropyPrimitive(_ entropy: ExtraEntropy) throws -> Primitive {
        try entropy.nonce().toPrimitive()
    }
}

// MARK: - Staking and extra config CBOR

extension ShelleyGenesisStaking {
    /// `[pools, stake]`: two `ListMap`s, definite-length maps in order.
    public init(from primitive: Primitive) throws {
        let f = try shelleyList(primitive, "ShelleyGenesisStaking")
        guard f.count == 2 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesisStaking: expected 2 fields, got \(f.count)")
        }
        var pools = OrderedDictionary<String, Primitive>()
        for (key, value) in try shelleyMapEntries(f[0], "ShelleyGenesisStaking pools", listMap: true) {
            pools[try shelleyBytes(key, 28, "staking pool key")] = try shelleyPoolParams(value)
        }
        var stake = OrderedDictionary<String, String>()
        for (key, value) in try shelleyMapEntries(f[1], "ShelleyGenesisStaking stake", listMap: true) {
            stake[try shelleyBytes(key, 28, "staking stake key")] = try shelleyBytes(value, 28, "staking stake pool")
        }
        self.init(pools: pools, stake: stake)
    }

    public func toPrimitive() throws -> Primitive {
        var poolEntries = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in pools {
            poolEntries[.bytes(try shelleyHexBytes(key, 28, "staking pool key"))] = try shelleyPoolParams(value)
        }
        var stakeEntries = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in stake {
            stakeEntries[.bytes(try shelleyHexBytes(key, 28, "staking stake key"))] =
                .bytes(try shelleyHexBytes(value, 28, "staking stake pool"))
        }
        return .list([.orderedDict(poolEntries), .orderedDict(stakeEntries)])
    }
}

extension ShelleyExtraConfig {
    /// `Rec ShelleyExtraConfig`: `[initialFunds, stakePools, stakeCredentials]`.
    public init(from primitive: Primitive) throws {
        let f = try shelleyList(primitive, "ShelleyExtraConfig")
        guard f.count == 3 else {
            throw CardanoCoreError.deserializeError("ShelleyExtraConfig: expected 3 fields, got \(f.count)")
        }
        self.init(
            initialFunds: try shelleyInjection(f[0], "initialFunds") {
                (try shelleyBytes($0, nil, "initialFunds address"),
                 try $1.integer("ShelleyExtraConfig initialFunds balance", as: Coin.self))
            },
            stakePools: try shelleyInjection(f[1], "stakePools") {
                (try shelleyBytes($0, 28, "stakePools key"), try shelleyPoolParams($1))
            },
            stakeCredentials: try shelleyInjection(f[2], "stakeCredentials") {
                (try shelleyBytes($0, 28, "stakeCredentials key"), try shelleyBytes($1, 28, "stakeCredentials pool"))
            })
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            try shelleyInjectionPrimitive(initialFunds) {
                (.bytes(try shelleyHexBytes($0, nil, "initialFunds address")), .integer($1))
            },
            try shelleyInjectionPrimitive(stakePools) {
                (.bytes(try shelleyHexBytes($0, 28, "stakePools key")), try shelleyPoolParams($1))
            },
            try shelleyInjectionPrimitive(stakeCredentials) {
                (.bytes(try shelleyHexBytes($0, 28, "stakeCredentials key")),
                 .bytes(try shelleyHexBytes($1, 28, "stakeCredentials pool")))
            },
        ])
    }
}

/// `InjectionData`: `[0]`, `[1, [segment, ...], hash]` or `[2, listMap]`.
fileprivate func shelleyInjection<V>(
    _ p: Primitive, _ what: String, _ entry: (Primitive, Primitive) throws -> (String, V)
) throws -> ShelleyGenesisInjection<V> {
    let f = try shelleyList(p, "InjectionData \(what)")
    guard let first = f.first else {
        throw CardanoCoreError.deserializeError("InjectionData \(what): empty")
    }
    switch try first.integer("InjectionData \(what) tag", as: UInt64.self) {
    case 0 where f.count == 1:
        return .none
    case 1 where f.count == 3:
        let path = try shelleyList(f[1], "InjectionData \(what) path").map { segment -> String in
            guard case .string(let s) = segment else {
                throw CardanoCoreError.deserializeError("InjectionData \(what): a path segment must be text")
            }
            return s
        }
        return .file(path: path, hash: try shelleyBytes(f[2], 32, "InjectionData \(what) hash"))
    case 2 where f.count == 2:
        var data = OrderedDictionary<String, V>()
        for (key, value) in try shelleyMapEntries(f[1], "InjectionData \(what)", listMap: true) {
            let (k, v) = try entry(key, value)
            data[k] = v
        }
        return .embedded(data)
    default:
        throw CardanoCoreError.deserializeError("InjectionData \(what): not an injection: \(p)")
    }
}

fileprivate func shelleyInjectionPrimitive<V>(
    _ value: ShelleyGenesisInjection<V>, _ entry: (String, V) throws -> (Primitive, Primitive)
) throws -> Primitive {
    switch value {
    case .none:
        return .list([.uint(0)])
    case .file(let path, let hash):
        return .list([.uint(1), .list(path.map { .string($0) }), .bytes(try shelleyHexBytes(hash, 32, "injection hash"))])
    case .embedded(let data):
        var entries = OrderedDictionary<Primitive, Primitive>()
        for (k, v) in data {
            let (key, val) = try entry(k, v)
            entries[key] = val
        }
        return .list([.uint(2), .orderedDict(entries)])
    }
}

/// A pool's `StakePoolParams`, kept as its CBOR: a 9-element list at the
/// Shelley protocol version.
fileprivate func shelleyPoolParams(_ p: Primitive) throws -> Primitive {
    guard try shelleyList(p, "StakePoolParams").count == 9 else {
        throw CardanoCoreError.deserializeError("StakePoolParams: expected 9 fields")
    }
    return p
}

// MARK: - UTCTime

/// A `UTCTime`, held exactly: the ledger writes it in CBOR as
/// `[year, dayOfYear, picosecondsOfDay]` (`encodeUTCTime`) and in JSON as
/// `2017-09-23T21:44:51Z`, with up to 12 decimals of a second.
fileprivate struct ShelleyUTCTime {
    let year: Int
    let dayOfYear: Int
    let picoseconds: BigUInt

    static let picosPerSecond = BigUInt(1_000_000_000_000)
    static let picosPerDay = BigUInt(86_400) * picosPerSecond

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }
    static func daysIn(_ y: Int) -> Int { isLeap(y) ? 366 : 365 }
    static func monthLengths(_ y: Int) -> [Int] { [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] }

    init(year: Int, dayOfYear: Int, picoseconds: BigUInt) throws {
        guard (0 ... 9999).contains(year) else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis systemStart: year \(year) is not in 0 ... 9999")
        }
        // A leap second can run the day to 86 401 seconds.
        guard picoseconds < Self.picosPerDay + Self.picosPerSecond else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis systemStart: \(picoseconds) ps is past the day")
        }
        self.year = year
        // `fromOrdinalDate` clips the day into the year.
        self.dayOfYear = min(max(dayOfYear, 1), Self.daysIn(year))
        self.picoseconds = picoseconds
    }

    /// `[year, dayOfYear, picosecondsOfDay]`.
    init(primitive: Primitive) throws {
        let f = try shelleyList(primitive, "ShelleyGenesis systemStart")
        guard f.count == 3 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis systemStart: a UTCTime has 3 fields")
        }
        guard let year = f[0].integerValue, let y = Int(exactly: year) else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis systemStart: bad year \(f[0])")
        }
        let day = try f[1].integer("ShelleyGenesis systemStart.dayOfYear", as: Int64.self)
        guard let picos = f[2].integerValue, picos >= 0 else {
            throw CardanoCoreError.deserializeError("ShelleyGenesis systemStart: bad picoseconds \(f[2])")
        }
        try self.init(year: y, dayOfYear: Int(day), picoseconds: picos.magnitude)
    }

    /// Parses `YYYY-MM-DDTHH:MM:SS[.fraction][Z|±HH:MM]`, as aeson reads a
    /// `UTCTime`, into UTC.
    init(iso text: String) throws {
        func fail() -> CardanoCoreError {
            CardanoCoreError.deserializeError("ShelleyGenesis systemStart: \(text) is not a UTCTime")
        }
        let chars = Array(text.utf8)
        var i = 0
        func number(_ count: Int) throws -> Int {
            guard i + count <= chars.count else { throw fail() }
            var value = 0
            for c in chars[i ..< i + count] {
                guard (48 ... 57).contains(c) else { throw fail() }
                value = value * 10 + Int(c - 48)
            }
            i += count
            return value
        }
        func expect(_ options: [UInt8]) throws {
            guard i < chars.count, options.contains(chars[i]) else { throw fail() }
            i += 1
        }
        let year = try number(4)
        try expect([45])
        let month = try number(2)
        try expect([45])
        let day = try number(2)
        try expect([84, 116, 32]) // T, t, space
        let hour = try number(2)
        try expect([58])
        let minute = try number(2)
        try expect([58])
        let second = try number(2)
        var fraction = BigUInt(0)
        if i < chars.count, chars[i] == 46 {
            i += 1
            var digits = 0
            while i < chars.count, (48 ... 57).contains(chars[i]) {
                // Picosecond precision: finer digits are dropped.
                if digits < 12 { fraction = fraction * 10 + BigUInt(chars[i] - 48) }
                digits += 1
                i += 1
            }
            guard digits > 0 else { throw fail() }
            for _ in min(digits, 12) ..< 12 { fraction *= 10 }
        }
        var offsetMinutes = 0
        if i < chars.count, chars[i] == 90 || chars[i] == 122 { // Z, z
            i += 1
        } else if i < chars.count, chars[i] == 43 || chars[i] == 45 { // +, -
            let sign = chars[i] == 45 ? -1 : 1
            i += 1
            let h = try number(2)
            var m = 0
            if i < chars.count, chars[i] == 58 { i += 1 }
            if i < chars.count { m = try number(2) }
            guard h < 24, m < 60 else { throw fail() }
            offsetMinutes = sign * (h * 60 + m)
        } else {
            throw fail()
        }
        guard i == chars.count, (1 ... 12).contains(month), hour < 24, minute < 60, second <= 60 else {
            throw fail()
        }
        let lengths = Self.monthLengths(year)
        guard (1 ... lengths[month - 1]).contains(day) else { throw fail() }
        var ordinal = lengths[..<(month - 1)].reduce(0, +) + day
        var y = year
        // Into UTC: subtract the offset, carrying into the next or last day.
        var seconds = hour * 3600 + minute * 60 + second - offsetMinutes * 60
        if seconds < 0 {
            seconds += 86_400
            ordinal -= 1
            if ordinal < 1 { y -= 1; ordinal = Self.daysIn(y) }
        } else if seconds >= 86_400, offsetMinutes != 0 {
            seconds -= 86_400
            ordinal += 1
            if ordinal > Self.daysIn(y) { y += 1; ordinal = 1 }
        }
        try self.init(year: y, dayOfYear: ordinal,
                      picoseconds: BigUInt(seconds) * Self.picosPerSecond + fraction)
    }

    /// `[year, dayOfYear, picosecondsOfDay]`.
    var primitive: Primitive {
        .list([.integer(year), .integer(dayOfYear), .integer(BigInt(picoseconds))])
    }

    /// The month and day of the ordinal day.
    private var monthDay: (Int, Int) {
        var rest = dayOfYear
        for (index, length) in Self.monthLengths(year).enumerated() {
            if rest <= length { return (index + 1, rest) }
            rest -= length
        }
        return (12, 31)
    }

    /// As aeson writes a `UTCTime`: `2017-09-23T21:44:51Z`, the fraction of a
    /// second without trailing zeros.
    var iso: String {
        let (month, day) = monthDay
        let (wholeSeconds, fraction) = picoseconds.quotientAndRemainder(dividingBy: Self.picosPerSecond)
        let total = Int(wholeSeconds)
        // A leap second is written as second 60 of the day's last minute.
        let (hour, minute, second) = total >= 86_400
            ? (23, 59, 60 + total - 86_400)
            : (total / 3600, total / 60 % 60, total % 60)
        func pad(_ v: Int, _ width: Int) -> String {
            let s = String(v)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        var text = "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))T\(pad(hour, 2)):\(pad(minute, 2)):\(pad(second, 2))"
        if fraction > 0 {
            var digits = String(fraction)
            digits = String(repeating: "0", count: 12 - digits.count) + digits
            while digits.hasSuffix("0") { digits.removeLast() }
            text += ".\(digits)"
        }
        return text + "Z"
    }

    /// The time as a `Date`, to a `Double`'s precision.
    var date: Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "UTC")
        components.year = year
        components.day = dayOfYear
        guard let start = components.date else { return nil }
        let seconds = Double(String(picoseconds / Self.picosPerSecond)) ?? 0
        let fraction = Double(String(picoseconds % Self.picosPerSecond)) ?? 0
        return start.addingTimeInterval(seconds + fraction / 1e12)
    }
}

// MARK: - Shared helpers

/// A dynamic JSON object key.
fileprivate struct ShelleyJSONKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// A JSON object at `key` as ordered pairs, in ascending key order: the
/// order the ledger's `ListMap` reads a JSON object in (aeson's `KeyMap`).
fileprivate func shelleyJSONMap<K: CodingKey, V: Decodable>(
    _ c: KeyedDecodingContainer<K>, _ key: K, _ type: V.Type, _ what: String
) throws -> [(String, V)] {
    let object = try c.nestedContainer(keyedBy: ShelleyJSONKey.self, forKey: key)
    let keys = object.allKeys.sorted {
        $0.stringValue.unicodeScalars.lexicographicallyPrecedes($1.stringValue.unicodeScalars)
    }
    return try keys.map { ($0.stringValue, try object.decode(V.self, forKey: $0)) }
}

fileprivate func shelleyHexData(_ text: String) -> Data? {
    let chars = Array(text.utf8)
    guard chars.count % 2 == 0 else { return nil }
    func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 48 ... 57: return c - 48
        case 65 ... 70: return c - 55
        case 97 ... 102: return c - 87
        default: return nil
        }
    }
    var data = Data(capacity: chars.count / 2)
    var i = 0
    while i < chars.count {
        guard let high = nibble(chars[i]), let low = nibble(chars[i + 1]) else { return nil }
        data.append(high << 4 | low)
        i += 2
    }
    return data
}

/// Hex text as bytes, of `length` when given.
fileprivate func shelleyHexBytes(_ text: String, _ length: Int?, _ what: String) throws -> Data {
    guard let data = shelleyHexData(text), length.map({ data.count == $0 }) ?? !data.isEmpty else {
        throw CardanoCoreError.valueError(
            "ShelleyGenesis \(what): \(text) is not \(length.map { "a \($0)-byte" } ?? "a") hex value")
    }
    return data
}

/// A hex hash of `length` bytes, normalised to lower case.
fileprivate func shelleyHash(_ text: String, _ length: Int, _ what: String) throws -> String {
    guard let data = shelleyHexData(text), data.count == length else {
        throw CardanoCoreError.deserializeError("ShelleyGenesis \(what): \(text) is not a \(length)-byte hex hash")
    }
    return data.toHex
}

/// A hex address (`Addr`'s JSON key), normalised to lower case.
fileprivate func shelleyAddress(_ text: String) throws -> String {
    guard let data = shelleyHexData(text), !data.isEmpty else {
        throw CardanoCoreError.deserializeError("ShelleyGenesis initialFunds: \(text) is not a hex address")
    }
    return data.toHex
}

/// A CBOR byte string as hex, of `length` bytes when given.
fileprivate func shelleyBytes(_ p: Primitive, _ length: Int?, _ what: String) throws -> String {
    let data: Data
    switch p {
    case .bytes(let d): data = d
    case .byteArray(let b): data = Data(b)
    case .byteString(let s): data = s.bytes
    default:
        throw CardanoCoreError.deserializeError("ShelleyGenesis \(what): expected bytes, got \(p)")
    }
    if let length, data.count != length {
        throw CardanoCoreError.deserializeError("ShelleyGenesis \(what): expected \(length) bytes, got \(data.count)")
    }
    return data.toHex
}

fileprivate func shelleyList(_ p: Primitive, _ what: String) throws -> [Primitive] {
    switch p {
    case .list(let items): return items
    case .indefiniteList(let items): return items.getAll()
    default: throw CardanoCoreError.deserializeError("\(what): expected a list, got \(p)")
    }
}

/// A CBOR map's entries. A `ListMap` is read with `decodeMapLen`, which takes
/// a definite-length map only.
fileprivate func shelleyMapEntries(_ p: Primitive, _ what: String, listMap: Bool) throws -> [(Primitive, Primitive)] {
    switch p {
    case .orderedDict(let d): return d.elements.map { ($0.key, $0.value) }
    case .dict(let d) where !listMap: return d.map { ($0.key, $0.value) }
    case .indefiniteDictionary(let d) where !listMap: return d.elements.map { ($0.key, $0.value) }
    default: throw CardanoCoreError.deserializeError("\(what): expected a definite-length map, got \(p)")
    }
}

// MARK: - Sendable
extension ShelleyGenesis: Sendable {}
extension ProtocolParams: Sendable {}
extension ProtocolParams.ProtocolVersion: Sendable {}
extension ProtocolParams.ExtraEntropy: Sendable {}
extension GenDelegation: Sendable {}
