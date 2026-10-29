import Foundation
import OrderedCollections
import CBORCodable
@preconcurrency import BigInt

public let ALONZO_COINS_PER_UTXO_WORD = 34482

/// An execution-unit count read from CBOR. The ledger holds it as a
/// `Natural`, but its CBOR decoder reads a `Word64` and refuses anything above
/// `Int64.max` (`ExUnits` in cardano-ledger-core).
internal func exUnitsParameter(_ primitive: Primitive, _ what: @autoclosure () -> String) throws -> UInt64 {
    let value = try primitive.integer(what(), as: UInt64.self)
    guard value <= UInt64(Int64.max) else {
        throw CardanoCoreError.deserializeError("\(what()): \(value) is above Int64.max")
    }
    return value
}

// MARK: - ProtocolParameters

public struct ProtocolParameters: Serializable, JSONLoadable {
    public let collateralPercentage: UInt16

    private var _coinsPerUtxoWord: Coin?
    /// Alonzo's `CoinPerWord`, a `Coin`.
    public var coinsPerUtxoWord: Coin {
        get {
            if let coinsPerUtxoWord = _coinsPerUtxoWord {
                return coinsPerUtxoWord
            } else {
                return Coin(ALONZO_COINS_PER_UTXO_WORD)
            }
        }
        set {
            _coinsPerUtxoWord = newValue
        }
    }

    public let committeeMaxTermLength: EpochInterval
    public let committeeMinSize: UInt16
    public let costModels: ProtocolParametersCostModels
    public let dRepActivity: EpochInterval
    public let dRepDeposit: Coin
    public let dRepVotingThresholds: DRepVotingThresholds
    public let executionUnitPrices: ExecutionUnitPrices
    public let govActionDeposit: Coin
    public let govActionLifetime: EpochInterval
    public let maxBlockBodySize: UInt32
    public let maxBlockExecutionUnits: ProtocolParametersExecutionUnits
    public let maxBlockHeaderSize: UInt16
    public let maxCollateralInputs: UInt16
    public let maxTxExecutionUnits: ProtocolParametersExecutionUnits
    public let maxTxSize: UInt32
    public let maxValueSize: UInt32
    public let maxReferenceScriptsSize: Int64?
    public let minFeeReferenceScripts: MinReferenceScriptsSize?
    /// A `NonNegativeInterval`, held exactly.
    public let minFeeRefScriptCostPerByte: NonNegativeInterval?
    public let minPoolCost: Coin
    /// `rho`, a `UnitInterval`, held exactly.
    public let monetaryExpansion: UnitInterval
    /// `a0`, a `NonNegativeInterval`, held exactly.
    public let poolPledgeInfluence: NonNegativeInterval
    public let poolRetireMaxEpoch: EpochInterval
    public let poolVotingThresholds: ProtocolParametersPoolVotingThresholds
    public let protocolVersion: ProtocolParametersProtocolVersion
    public let stakeAddressDeposit: Coin
    public let stakePoolDeposit: Coin
    public let stakePoolTargetNum: UInt16
    /// `tau`, a `UnitInterval`, held exactly.
    public let treasuryCut: UnitInterval
    public let txFeeFixed: Coin
    public let txFeePerByte: Coin
    public let utxoCostPerByte: Coin

    // MARK: JSON CodingKeys — camelCase names matching the Ogmios/blockfrost API

    private enum JSONCodingKeys: String, CodingKey {
        case collateralPercentage
        case coinsPerUtxoWord
        case committeeMaxTermLength
        case committeeMinSize
        case costModels
        case dRepActivity
        case dRepDeposit
        case dRepVotingThresholds
        case executionUnitPrices
        case govActionDeposit
        case govActionLifetime
        case maxBlockBodySize
        case maxBlockExecutionUnits
        case maxBlockHeaderSize
        case maxCollateralInputs
        case maxTxExecutionUnits
        case maxTxSize
        case maxValueSize
        case maxReferenceScriptsSize
        case minFeeReferenceScripts
        case minFeeRefScriptCostPerByte
        case minPoolCost
        case monetaryExpansion
        case poolPledgeInfluence
        case poolRetireMaxEpoch
        case poolVotingThresholds
        case protocolVersion
        case stakeAddressDeposit
        case stakePoolDeposit
        case stakePoolTargetNum
        case treasuryCut
        case txFeeFixed
        case txFeePerByte
        case utxoCostPerByte
    }

    // MARK: CBOR CodingKeys — Conway CDDL integer keys for protocol_param_update

    private enum CBORCodingKeys: Int, CodingKey {
        case minFeeA = 0
        case minFeeB = 1
        case maxBlockBodySize = 2
        case maxTxSize = 3
        case maxBlockHeaderSize = 4
        case keyDeposit = 5
        case poolDeposit = 6
        case maximumEpoch = 7
        case nOpt = 8
        case poolPledgeInfluence = 9
        case expansionRate = 10
        case treasuryGrowthRate = 11
        case protocolVersion = 14
        case minPoolCost = 16
        case adaPerUtxoByte = 17
        case costModels = 18
        case executionCosts = 19
        case maxTxExUnits = 20
        case maxBlockExUnits = 21
        case maxValueSize = 22
        case collateralPercentage = 23
        case maxCollateralInputs = 24
        case poolVotingThresholds = 25
        case drepVotingThresholds = 26
        case minCommitteeSize = 27
        case committeeTermLimit = 28
        case govActionValidityPeriod = 29
        case govActionDeposit = 30
        case drepDeposit = 31
        case drepInactivityPeriod = 32
        case minFeeRefScriptCoinsPerByte = 33
    }

    public init(collateralPercentage: UInt16,
                coinsPerUtxoWord: Coin? = nil,
                committeeMaxTermLength: EpochInterval,
                committeeMinSize: UInt16,
                costModels: ProtocolParametersCostModels,
                dRepActivity: EpochInterval,
                dRepDeposit: Coin,
                dRepVotingThresholds: DRepVotingThresholds,
                executionUnitPrices: ExecutionUnitPrices,
                govActionDeposit: Coin,
                govActionLifetime: EpochInterval,
                maxBlockBodySize: UInt32,
                maxBlockExecutionUnits: ProtocolParametersExecutionUnits,
                maxBlockHeaderSize: UInt16,
                maxCollateralInputs: UInt16,
                maxTxExecutionUnits: ProtocolParametersExecutionUnits,
                maxTxSize: UInt32,
                maxValueSize: UInt32,
                maxReferenceScriptsSize: Int64? = nil,
                minFeeReferenceScripts: MinReferenceScriptsSize? = nil,
                minFeeRefScriptCostPerByte: NonNegativeInterval? = nil,
                minPoolCost: Coin,
                monetaryExpansion: UnitInterval,
                poolPledgeInfluence: NonNegativeInterval,
                poolRetireMaxEpoch: EpochInterval,
                poolVotingThresholds: ProtocolParametersPoolVotingThresholds,
                protocolVersion: ProtocolParametersProtocolVersion,
                stakeAddressDeposit: Coin,
                stakePoolDeposit: Coin,
                stakePoolTargetNum: UInt16,
                treasuryCut: UnitInterval,
                txFeeFixed: Coin,
                txFeePerByte: Coin,
                utxoCostPerByte: Coin
    ) {
        self.collateralPercentage = collateralPercentage
        self._coinsPerUtxoWord = coinsPerUtxoWord
        self.committeeMaxTermLength = committeeMaxTermLength
        self.committeeMinSize = committeeMinSize
        self.costModels = costModels
        self.dRepActivity = dRepActivity
        self.dRepDeposit = dRepDeposit
        self.dRepVotingThresholds = dRepVotingThresholds
        self.executionUnitPrices = executionUnitPrices
        self.govActionDeposit = govActionDeposit
        self.govActionLifetime = govActionLifetime
        self.maxBlockBodySize = maxBlockBodySize
        self.maxBlockExecutionUnits = maxBlockExecutionUnits
        self.maxBlockHeaderSize = maxBlockHeaderSize
        self.maxCollateralInputs = maxCollateralInputs
        self.maxTxExecutionUnits = maxTxExecutionUnits
        self.maxTxSize = maxTxSize
        self.maxValueSize = maxValueSize
        self.maxReferenceScriptsSize = maxReferenceScriptsSize
        self.minFeeReferenceScripts = minFeeReferenceScripts
        self.minFeeRefScriptCostPerByte = minFeeRefScriptCostPerByte
        self.minPoolCost = minPoolCost
        self.monetaryExpansion = monetaryExpansion
        self.poolPledgeInfluence = poolPledgeInfluence
        self.poolRetireMaxEpoch = poolRetireMaxEpoch
        self.poolVotingThresholds = poolVotingThresholds
        self.protocolVersion = protocolVersion
        self.stakeAddressDeposit = stakeAddressDeposit
        self.stakePoolDeposit = stakePoolDeposit
        self.stakePoolTargetNum = stakePoolTargetNum
        self.treasuryCut = treasuryCut
        self.txFeeFixed = txFeeFixed
        self.txFeePerByte = txFeePerByte
        self.utxoCostPerByte = utxoCostPerByte
    }

    // MARK: Codable — dispatches JSON vs CBOR
    // Uses JSON keyed container (string keys) or CBOR keyed container (integer keys).
    // Both branches delegate to self.init() so this is a delegating initializer.

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: JSONCodingKeys.self)
            let collateralPercentage    = try c.decode(UInt16.self, forKey: .collateralPercentage)
            let coinsPerUtxoWord        = try c.decodeIfPresent(Coin.self, forKey: .coinsPerUtxoWord)
            let committeeMaxTermLength  = try c.decode(EpochInterval.self, forKey: .committeeMaxTermLength)
            let committeeMinSize        = try c.decode(UInt16.self, forKey: .committeeMinSize)
            let costModels              = try c.decode(ProtocolParametersCostModels.self, forKey: .costModels)
            let dRepActivity            = try c.decode(EpochInterval.self, forKey: .dRepActivity)
            let dRepDeposit             = try c.decode(Coin.self, forKey: .dRepDeposit)
            let dRepVotingThresholds    = try c.decode(DRepVotingThresholds.self, forKey: .dRepVotingThresholds)
            let executionUnitPrices     = try c.decode(ExecutionUnitPrices.self, forKey: .executionUnitPrices)
            let govActionDeposit        = try c.decode(Coin.self, forKey: .govActionDeposit)
            let govActionLifetime       = try c.decode(EpochInterval.self, forKey: .govActionLifetime)
            let maxBlockBodySize        = try c.decode(UInt32.self, forKey: .maxBlockBodySize)
            let maxBlockExecutionUnits  = try c.decode(ProtocolParametersExecutionUnits.self, forKey: .maxBlockExecutionUnits)
            let maxBlockHeaderSize      = try c.decode(UInt16.self, forKey: .maxBlockHeaderSize)
            let maxCollateralInputs     = try c.decode(UInt16.self, forKey: .maxCollateralInputs)
            let maxTxExecutionUnits     = try c.decode(ProtocolParametersExecutionUnits.self, forKey: .maxTxExecutionUnits)
            let maxTxSize               = try c.decode(UInt32.self, forKey: .maxTxSize)
            let maxValueSize            = try c.decode(UInt32.self, forKey: .maxValueSize)
            let maxReferenceScriptsSize     = try c.decodeIfPresent(Int64.self, forKey: .maxReferenceScriptsSize)
            let minFeeReferenceScripts      = try c.decodeIfPresent(MinReferenceScriptsSize.self, forKey: .minFeeReferenceScripts)
            let minFeeRefScriptCostPerByte  = try c.decodeNonNegativeIntervalIfPresent(forKey: .minFeeRefScriptCostPerByte)
            let minPoolCost             = try c.decode(Coin.self, forKey: .minPoolCost)
            // Rationals are read from the number's text exactly, as the
            // ledger reads a JSON number into a `BoundedRatio Word64`.
            let monetaryExpansion       = try c.decodeUnitInterval(forKey: .monetaryExpansion)
            let poolPledgeInfluence     = try c.decodeNonNegativeInterval(forKey: .poolPledgeInfluence)
            let poolRetireMaxEpoch      = try c.decode(EpochInterval.self, forKey: .poolRetireMaxEpoch)
            let poolVotingThresholds    = try c.decode(ProtocolParametersPoolVotingThresholds.self, forKey: .poolVotingThresholds)
            let protocolVersion         = try c.decode(ProtocolParametersProtocolVersion.self, forKey: .protocolVersion)
            let stakeAddressDeposit     = try c.decode(Coin.self, forKey: .stakeAddressDeposit)
            let stakePoolDeposit        = try c.decode(Coin.self, forKey: .stakePoolDeposit)
            let stakePoolTargetNum      = try c.decode(UInt16.self, forKey: .stakePoolTargetNum)
            let treasuryCut             = try c.decodeUnitInterval(forKey: .treasuryCut)
            let txFeeFixed              = try c.decode(Coin.self, forKey: .txFeeFixed)
            let txFeePerByte            = try c.decode(Coin.self, forKey: .txFeePerByte)
            let utxoCostPerByte         = try c.decode(Coin.self, forKey: .utxoCostPerByte)
            self.init(
                collateralPercentage: collateralPercentage,
                coinsPerUtxoWord: coinsPerUtxoWord,
                committeeMaxTermLength: committeeMaxTermLength,
                committeeMinSize: committeeMinSize,
                costModels: costModels,
                dRepActivity: dRepActivity,
                dRepDeposit: dRepDeposit,
                dRepVotingThresholds: dRepVotingThresholds,
                executionUnitPrices: executionUnitPrices,
                govActionDeposit: govActionDeposit,
                govActionLifetime: govActionLifetime,
                maxBlockBodySize: maxBlockBodySize,
                maxBlockExecutionUnits: maxBlockExecutionUnits,
                maxBlockHeaderSize: maxBlockHeaderSize,
                maxCollateralInputs: maxCollateralInputs,
                maxTxExecutionUnits: maxTxExecutionUnits,
                maxTxSize: maxTxSize,
                maxValueSize: maxValueSize,
                maxReferenceScriptsSize: maxReferenceScriptsSize,
                minFeeReferenceScripts: minFeeReferenceScripts,
                minFeeRefScriptCostPerByte: minFeeRefScriptCostPerByte,
                minPoolCost: minPoolCost,
                monetaryExpansion: monetaryExpansion,
                poolPledgeInfluence: poolPledgeInfluence,
                poolRetireMaxEpoch: poolRetireMaxEpoch,
                poolVotingThresholds: poolVotingThresholds,
                protocolVersion: protocolVersion,
                stakeAddressDeposit: stakeAddressDeposit,
                stakePoolDeposit: stakePoolDeposit,
                stakePoolTargetNum: stakePoolTargetNum,
                treasuryCut: treasuryCut,
                txFeeFixed: txFeeFixed,
                txFeePerByte: txFeePerByte,
                utxoCostPerByte: utxoCostPerByte
            )
        } else {
            // CBOR path: decode via Primitive so init(from primitive:) handles both
            // the map format (protocol_param_update) and the n2c 31-element array.
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: JSONCodingKeys.self)
            try c.encode(collateralPercentage, forKey: .collateralPercentage)
            try c.encodeIfPresent(_coinsPerUtxoWord, forKey: .coinsPerUtxoWord)
            try c.encode(committeeMaxTermLength, forKey: .committeeMaxTermLength)
            try c.encode(committeeMinSize, forKey: .committeeMinSize)
            try c.encode(costModels, forKey: .costModels)
            try c.encode(dRepActivity, forKey: .dRepActivity)
            try c.encode(dRepDeposit, forKey: .dRepDeposit)
            try c.encode(dRepVotingThresholds, forKey: .dRepVotingThresholds)
            try c.encode(executionUnitPrices, forKey: .executionUnitPrices)
            try c.encode(govActionDeposit, forKey: .govActionDeposit)
            try c.encode(govActionLifetime, forKey: .govActionLifetime)
            try c.encode(maxBlockBodySize, forKey: .maxBlockBodySize)
            try c.encode(maxBlockExecutionUnits, forKey: .maxBlockExecutionUnits)
            try c.encode(maxBlockHeaderSize, forKey: .maxBlockHeaderSize)
            try c.encode(maxCollateralInputs, forKey: .maxCollateralInputs)
            try c.encode(maxTxExecutionUnits, forKey: .maxTxExecutionUnits)
            try c.encode(maxTxSize, forKey: .maxTxSize)
            try c.encode(maxValueSize, forKey: .maxValueSize)
            try c.encodeIfPresent(maxReferenceScriptsSize, forKey: .maxReferenceScriptsSize)
            try c.encodeIfPresent(minFeeReferenceScripts, forKey: .minFeeReferenceScripts)
            try c.encodeLedgerRationalIfPresent(minFeeRefScriptCostPerByte, forKey: .minFeeRefScriptCostPerByte)
            try c.encode(minPoolCost, forKey: .minPoolCost)
            try c.encodeLedgerRational(monetaryExpansion, forKey: .monetaryExpansion)
            try c.encodeLedgerRational(poolPledgeInfluence, forKey: .poolPledgeInfluence)
            try c.encode(poolRetireMaxEpoch, forKey: .poolRetireMaxEpoch)
            try c.encode(poolVotingThresholds, forKey: .poolVotingThresholds)
            try c.encode(protocolVersion, forKey: .protocolVersion)
            try c.encode(stakeAddressDeposit, forKey: .stakeAddressDeposit)
            try c.encode(stakePoolDeposit, forKey: .stakePoolDeposit)
            try c.encode(stakePoolTargetNum, forKey: .stakePoolTargetNum)
            try c.encodeLedgerRational(treasuryCut, forKey: .treasuryCut)
            try c.encode(txFeeFixed, forKey: .txFeeFixed)
            try c.encode(txFeePerByte, forKey: .txFeePerByte)
            try c.encode(utxoCostPerByte, forKey: .utxoCostPerByte)
        } else {
            // CBOR path: encode via Primitive to ensure an integer-keyed CBOR map.
            // PotentCBOR's keyed container uses key.stringValue regardless of CodingKey.intValue,
            // so we sidestep it by emitting the map through toPrimitive().
            var c = encoder.singleValueContainer()
            try c.encode(try toPrimitive())
        }
    }

    // MARK: CBORSerializable — toPrimitive / init(from primitive:)
    // These are used for direct Primitive manipulation (e.g. embedding in ParameterChangeAction).
    // The CBOR encode/decode path above uses keyed containers for reliable round-tripping.

    /// Conway CDDL key assignments for protocol_param_update / current_pparams.
    enum CBORKey: Int64 {
        case minFeeA = 0, minFeeB = 1, maxBlockBodySize = 2, maxTxSize = 3, maxBlockHeaderSize = 4
        case keyDeposit = 5, poolDeposit = 6, maximumEpoch = 7, nOpt = 8, poolPledgeInfluence = 9
        case expansionRate = 10, treasuryGrowthRate = 11
        case protocolVersion = 14, minPoolCost = 16, adaPerUtxoByte = 17
        case costModels = 18, executionCosts = 19, maxTxExUnits = 20, maxBlockExUnits = 21
        case maxValueSize = 22, collateralPercentage = 23, maxCollateralInputs = 24
        case poolVotingThresholds = 25, drepVotingThresholds = 26
        case minCommitteeSize = 27, committeeTermLimit = 28, govActionValidityPeriod = 29
        case govActionDeposit = 30, drepDeposit = 31, drepInactivityPeriod = 32
        case minFeeRefScriptCoinsPerByte = 33
    }

    public init(from primitive: Primitive) throws {
        // Accept both .dict and .orderedDict since CBOR round-trips produce .orderedDict.
        // Also accept the n2c 31-element positional array (node-to-client wire format).
        switch primitive {
        case .list(let elements) where elements.count == 31:
            try self.init(fromN2CArray: elements)
            return
        default:
            break
        }

        let pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d):
            pairs = d.map { ($0.key, $0.value) }
        case .orderedDict(let d):
            pairs = d.elements.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("ProtocolParameters CBOR must be a map")
        }

        var map = [Int64: Primitive]()
        for (k, v) in pairs {
            map[try k.integer("ProtocolParameters CBOR key", as: Int64.self)] = v
        }

        /// The parameter at `key`, read as the ledger's `T` (`coin` is a
        /// `UInt64`, `uint .size 4` a `UInt32`, and so on).
        func intVal<T: FixedWidthInteger & UnsignedInteger>(
            _ key: CBORKey, as type: T.Type = UInt64.self
        ) throws -> T {
            guard let p = map[key.rawValue] else {
                throw CardanoCoreError.deserializeError("Missing CBOR key \(key.rawValue)")
            }
            return try p.integer("ProtocolParameters CBOR key \(key.rawValue)", as: T.self)
        }

        func require(_ key: CBORKey) throws -> Primitive {
            guard let p = map[key.rawValue] else {
                throw CardanoCoreError.deserializeError("Missing CBOR key \(key.rawValue)")
            }
            return p
        }

        let txFeePerByte        = try intVal(.minFeeA)
        let txFeeFixed          = try intVal(.minFeeB)
        let maxBlockBodySize    = try intVal(.maxBlockBodySize, as: UInt32.self)
        let maxTxSize           = try intVal(.maxTxSize, as: UInt32.self)
        let maxBlockHeaderSize  = try intVal(.maxBlockHeaderSize, as: UInt16.self)
        let stakeAddressDeposit = try intVal(.keyDeposit)
        let stakePoolDeposit    = try intVal(.poolDeposit)
        let poolRetireMaxEpoch  = try intVal(.maximumEpoch, as: UInt32.self)
        let stakePoolTargetNum  = try intVal(.nOpt, as: UInt16.self)

        // Rationals as the ledger reads them: `#6.30` pairs, reduced, within
        // the range of their type.
        let poolPledgeInfluence = try NonNegativeInterval.ledgerCBOR(require(.poolPledgeInfluence), "poolPledgeInfluence")
        let monetaryExpansion   = try UnitInterval.ledgerCBOR(require(.expansionRate), "monetaryExpansion")
        let treasuryCut         = try UnitInterval.ledgerCBOR(require(.treasuryGrowthRate), "treasuryCut")

        let pv = try ProtocolVersion(from: require(.protocolVersion))
        guard let pvMajor = UInt32(exactly: pv.major ?? 0), let pvMinor = UInt32(exactly: pv.minor ?? 0) else {
            throw CardanoCoreError.deserializeError("ProtocolParameters protocolVersion is out of range for UInt32")
        }
        let protocolVersion = ProtocolParametersProtocolVersion(major: pvMajor, minor: pvMinor)

        let minPoolCost     = try intVal(.minPoolCost)
        let utxoCostPerByte = try intVal(.adaPerUtxoByte)

        let cborCM = try CostModels(from: require(.costModels))
        let costModels = ProtocolParametersCostModels(
            PlutusV1: cborCM.plutusV1.map { Array($0.values) } ?? [],
            PlutusV2: cborCM.plutusV2.map { Array($0.values) } ?? [],
            PlutusV3: cborCM.plutusV3.map { Array($0.values) } ?? []
        )

        let executionUnitPrices = try ExecutionUnitPrices(cbor: require(.executionCosts), "executionCosts")

        let txU = try ExUnits(from: require(.maxTxExUnits))
        let maxTxExecutionUnits = ProtocolParametersExecutionUnits(
            memory: try exUnitsParameter(.uint(txU.mem), "maxTxExUnits mem"),
            steps: try exUnitsParameter(.uint(txU.steps), "maxTxExUnits steps")
        )
        let blkU = try ExUnits(from: require(.maxBlockExUnits))
        let maxBlockExecutionUnits = ProtocolParametersExecutionUnits(
            memory: try exUnitsParameter(.uint(blkU.mem), "maxBlockExUnits mem"),
            steps: try exUnitsParameter(.uint(blkU.steps), "maxBlockExUnits steps")
        )

        let maxValueSize         = try intVal(.maxValueSize, as: UInt32.self)
        let collateralPercentage = try intVal(.collateralPercentage, as: UInt16.self)
        let maxCollateralInputs  = try intVal(.maxCollateralInputs, as: UInt16.self)

        let poolVotingThresholds = try ProtocolParametersPoolVotingThresholds(cbor: require(.poolVotingThresholds))
        let dRepVotingThresholds = try DRepVotingThresholds(cbor: require(.drepVotingThresholds))

        let committeeMinSize       = try intVal(.minCommitteeSize, as: UInt16.self)
        let committeeMaxTermLength = try intVal(.committeeTermLimit, as: UInt32.self)
        let govActionLifetime      = try intVal(.govActionValidityPeriod, as: UInt32.self)
        let govActionDeposit       = try intVal(.govActionDeposit)
        let dRepDeposit            = try intVal(.drepDeposit)
        let dRepActivity           = try intVal(.drepInactivityPeriod, as: UInt32.self)

        // A NonNegativeInterval in the ledger: the whole rational, not just
        // its numerator.
        let minFeeRefScriptCostPerByte = try map[CBORKey.minFeeRefScriptCoinsPerByte.rawValue].map {
            try NonNegativeInterval.ledgerCBOR($0, "minFeeRefScriptCostPerByte")
        }

        self.init(
            collateralPercentage: collateralPercentage,
            committeeMaxTermLength: committeeMaxTermLength,
            committeeMinSize: committeeMinSize,
            costModels: costModels,
            dRepActivity: dRepActivity,
            dRepDeposit: dRepDeposit,
            dRepVotingThresholds: dRepVotingThresholds,
            executionUnitPrices: executionUnitPrices,
            govActionDeposit: govActionDeposit,
            govActionLifetime: govActionLifetime,
            maxBlockBodySize: maxBlockBodySize,
            maxBlockExecutionUnits: maxBlockExecutionUnits,
            maxBlockHeaderSize: maxBlockHeaderSize,
            maxCollateralInputs: maxCollateralInputs,
            maxTxExecutionUnits: maxTxExecutionUnits,
            maxTxSize: maxTxSize,
            maxValueSize: maxValueSize,
            minFeeRefScriptCostPerByte: minFeeRefScriptCostPerByte,
            minPoolCost: minPoolCost,
            monetaryExpansion: monetaryExpansion,
            poolPledgeInfluence: poolPledgeInfluence,
            poolRetireMaxEpoch: poolRetireMaxEpoch,
            poolVotingThresholds: poolVotingThresholds,
            protocolVersion: protocolVersion,
            stakeAddressDeposit: stakeAddressDeposit,
            stakePoolDeposit: stakePoolDeposit,
            stakePoolTargetNum: stakePoolTargetNum,
            treasuryCut: treasuryCut,
            txFeeFixed: txFeeFixed,
            txFeePerByte: txFeePerByte,
            utxoCostPerByte: utxoCostPerByte
        )
    }

    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]

        dict[.int(CBORKey.minFeeA.rawValue)]          = .integer(txFeePerByte)
        dict[.int(CBORKey.minFeeB.rawValue)]          = .integer(txFeeFixed)
        dict[.int(CBORKey.maxBlockBodySize.rawValue)]  = .integer(maxBlockBodySize)
        dict[.int(CBORKey.maxTxSize.rawValue)]         = .integer(maxTxSize)
        dict[.int(CBORKey.maxBlockHeaderSize.rawValue)] = .integer(maxBlockHeaderSize)
        dict[.int(CBORKey.keyDeposit.rawValue)]        = .integer(stakeAddressDeposit)
        dict[.int(CBORKey.poolDeposit.rawValue)]       = .integer(stakePoolDeposit)
        dict[.int(CBORKey.maximumEpoch.rawValue)]      = .integer(poolRetireMaxEpoch)
        dict[.int(CBORKey.nOpt.rawValue)]              = .integer(stakePoolTargetNum)

        // The ledger's CBOR decoder refuses execution units above Int64.max.
        func exUnit(_ value: UInt64, _ what: String) throws -> UInt64 {
            guard value <= UInt64(Int64.max) else {
                throw CardanoCoreError.valueError("\(what): \(value) is above Int64.max")
            }
            return value
        }

        // Rationals as the ledger writes them: reduced, as `#6.30` pairs. A
        // value outside its type's range is refused rather than written.
        try LedgerRational.check(poolPledgeInfluence.numerator, poolPledgeInfluence.denominator,
                                 .nonNegativeInterval, "poolPledgeInfluence")
        try LedgerRational.check(monetaryExpansion.numerator, monetaryExpansion.denominator,
                                 .unitInterval, "monetaryExpansion")
        try LedgerRational.check(treasuryCut.numerator, treasuryCut.denominator, .unitInterval, "treasuryCut")
        dict[.int(CBORKey.poolPledgeInfluence.rawValue)] = poolPledgeInfluence.ledgerPrimitive()
        dict[.int(CBORKey.expansionRate.rawValue)] = monetaryExpansion.ledgerPrimitive()
        dict[.int(CBORKey.treasuryGrowthRate.rawValue)] = treasuryCut.ledgerPrimitive()

        dict[.int(CBORKey.protocolVersion.rawValue)] = try ProtocolVersion(
            major: Int(protocolVersion.major), minor: Int(protocolVersion.minor)
        ).toPrimitive()

        dict[.int(CBORKey.minPoolCost.rawValue)]    = .integer(minPoolCost)
        dict[.int(CBORKey.adaPerUtxoByte.rawValue)] = .integer(utxoCostPerByte)

        // Round-trip the raw cost-model values directly. CostModels.init validates
        // each array against a hardcoded template (e.g. PlutusV1 = 166 entries),
        // which can't represent on-chain encodings that the wire actually emits
        // (newer Conway nodes have been observed sending 332-int arrays). Skip
        // the validation so values that decoded successfully also re-encode.
        var cmDict: [Primitive: Primitive] = [:]
        if !costModels.PlutusV1.isEmpty {
            cmDict[.int(0)] = .indefiniteList(IndefiniteList(costModels.PlutusV1.map { Primitive.int($0) }))
        }
        if !costModels.PlutusV2.isEmpty {
            cmDict[.int(1)] = .indefiniteList(IndefiniteList(costModels.PlutusV2.map { Primitive.int($0) }))
        }
        if !costModels.PlutusV3.isEmpty {
            cmDict[.int(2)] = .indefiniteList(IndefiniteList(costModels.PlutusV3.map { Primitive.int($0) }))
        }
        dict[.int(CBORKey.costModels.rawValue)] = .dict(cmDict)

        dict[.int(CBORKey.executionCosts.rawValue)] = try executionUnitPrices.ledgerPrimitive()

        dict[.int(CBORKey.maxTxExUnits.rawValue)] = try ExUnits(
            mem: try exUnit(maxTxExecutionUnits.memory, "maxTxExecutionUnits memory"),
            steps: try exUnit(maxTxExecutionUnits.steps, "maxTxExecutionUnits steps")
        ).toPrimitive()
        dict[.int(CBORKey.maxBlockExUnits.rawValue)] = try ExUnits(
            mem: try exUnit(maxBlockExecutionUnits.memory, "maxBlockExecutionUnits memory"),
            steps: try exUnit(maxBlockExecutionUnits.steps, "maxBlockExecutionUnits steps")
        ).toPrimitive()

        dict[.int(CBORKey.maxValueSize.rawValue)]         = .integer(maxValueSize)
        dict[.int(CBORKey.collateralPercentage.rawValue)]  = .integer(collateralPercentage)
        dict[.int(CBORKey.maxCollateralInputs.rawValue)]   = .integer(maxCollateralInputs)

        dict[.int(CBORKey.poolVotingThresholds.rawValue)] = try poolVotingThresholds.ledgerPrimitive()
        dict[.int(CBORKey.drepVotingThresholds.rawValue)] = try dRepVotingThresholds.ledgerPrimitive()

        dict[.int(CBORKey.minCommitteeSize.rawValue)]       = .integer(committeeMinSize)
        dict[.int(CBORKey.committeeTermLimit.rawValue)]     = .integer(committeeMaxTermLength)
        dict[.int(CBORKey.govActionValidityPeriod.rawValue)] = .integer(govActionLifetime)
        dict[.int(CBORKey.govActionDeposit.rawValue)]       = .integer(govActionDeposit)
        dict[.int(CBORKey.drepDeposit.rawValue)]            = .integer(dRepDeposit)
        dict[.int(CBORKey.drepInactivityPeriod.rawValue)]   = .integer(dRepActivity)
        if let minFeeRefScriptCostPerByte {
            try LedgerRational.check(minFeeRefScriptCostPerByte.numerator, minFeeRefScriptCostPerByte.denominator,
                                     .nonNegativeInterval, "minFeeRefScriptCostPerByte")
            dict[.int(CBORKey.minFeeRefScriptCoinsPerByte.rawValue)] = minFeeRefScriptCostPerByte.ledgerPrimitive()
        }

        return .dict(dict)
    }

    // MARK: - n2c positional-array initializer

    /// Decode from the 31-element positional CBOR array emitted by the n2c protocol.
    /// Conway CDDL positional order matches CBORKey assignments, with gaps at 12, 13, 15.
    private init(fromN2CArray elements: [Primitive]) throws {
        /// The parameter at `idx`, read as the ledger's `T`.
        func uint<T: FixedWidthInteger & UnsignedInteger>(
            _ idx: Int, as type: T.Type = UInt64.self
        ) throws -> T {
            try elements[idx].integer("n2c pparams position \(idx)", as: T.self)
        }

        let txFeePerByte        = try uint(0)
        let txFeeFixed          = try uint(1)
        let maxBlockBodySize    = try uint(2, as: UInt32.self)
        let maxTxSize           = try uint(3, as: UInt32.self)
        let maxBlockHeaderSize  = try uint(4, as: UInt16.self)
        let stakeAddressDeposit = try uint(5)
        let stakePoolDeposit    = try uint(6)
        let poolRetireMaxEpoch  = try uint(7, as: UInt32.self)
        let stakePoolTargetNum  = try uint(8, as: UInt16.self)

        let poolPledgeInfluence = try NonNegativeInterval.ledgerCBOR(elements[9], "n2c poolPledgeInfluence")
        let monetaryExpansion   = try UnitInterval.ledgerCBOR(elements[10], "n2c monetaryExpansion")
        let treasuryCut         = try UnitInterval.ledgerCBOR(elements[11], "n2c treasuryCut")

        guard case .list(let pvArr) = elements[12], pvArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid protocolVersion at n2c position 12")
        }
        let pvMajor = try pvArr[0].integer("n2c protocol major", as: UInt32.self)
        let pvMinor = try pvArr[1].integer("n2c protocol minor", as: UInt32.self)
        let protocolVersion = ProtocolParametersProtocolVersion(major: pvMajor, minor: pvMinor)

        let minPoolCost     = try uint(13)
        let utxoCostPerByte = try uint(14)

        let costModels = try ProtocolParameters.decodeCostModelsRaw(elements[15])

        let executionUnitPrices = try ExecutionUnitPrices(cbor: elements[16], "n2c executionCosts")

        guard case .list(let txExArr) = elements[17], txExArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid maxTxExUnits at n2c position 17")
        }
        let maxTxExecutionUnits = ProtocolParametersExecutionUnits(
            memory: try exUnitsParameter(txExArr[0], "n2c maxTxExUnits mem"),
            steps:  try exUnitsParameter(txExArr[1], "n2c maxTxExUnits steps")
        )

        guard case .list(let blkExArr) = elements[18], blkExArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid maxBlockExUnits at n2c position 18")
        }
        let maxBlockExecutionUnits = ProtocolParametersExecutionUnits(
            memory: try exUnitsParameter(blkExArr[0], "n2c maxBlockExUnits mem"),
            steps:  try exUnitsParameter(blkExArr[1], "n2c maxBlockExUnits steps")
        )

        let maxValueSize         = try uint(19, as: UInt32.self)
        let collateralPercentage = try uint(20, as: UInt16.self)
        let maxCollateralInputs  = try uint(21, as: UInt16.self)

        let poolVotingThresholds = try ProtocolParametersPoolVotingThresholds(cbor: elements[22])
        let dRepVotingThresholds = try DRepVotingThresholds(cbor: elements[23])

        let committeeMinSize       = try uint(24, as: UInt16.self)
        let committeeMaxTermLength = try uint(25, as: UInt32.self)
        let govActionLifetime      = try uint(26, as: UInt32.self)
        let govActionDeposit       = try uint(27)
        let dRepDeposit            = try uint(28)
        let dRepActivity           = try uint(29, as: UInt32.self)
        let minFeeRefScriptCostPerByte = try NonNegativeInterval.ledgerCBOR(elements[30], "n2c minFeeRefScriptCostPerByte")

        self.init(
            collateralPercentage: collateralPercentage,
            committeeMaxTermLength: committeeMaxTermLength,
            committeeMinSize: committeeMinSize,
            costModels: costModels,
            dRepActivity: dRepActivity,
            dRepDeposit: dRepDeposit,
            dRepVotingThresholds: dRepVotingThresholds,
            executionUnitPrices: executionUnitPrices,
            govActionDeposit: govActionDeposit,
            govActionLifetime: govActionLifetime,
            maxBlockBodySize: maxBlockBodySize,
            maxBlockExecutionUnits: maxBlockExecutionUnits,
            maxBlockHeaderSize: maxBlockHeaderSize,
            maxCollateralInputs: maxCollateralInputs,
            maxTxExecutionUnits: maxTxExecutionUnits,
            maxTxSize: maxTxSize,
            maxValueSize: maxValueSize,
            minFeeRefScriptCostPerByte: minFeeRefScriptCostPerByte,
            minPoolCost: minPoolCost,
            monetaryExpansion: monetaryExpansion,
            poolPledgeInfluence: poolPledgeInfluence,
            poolRetireMaxEpoch: poolRetireMaxEpoch,
            poolVotingThresholds: poolVotingThresholds,
            protocolVersion: protocolVersion,
            stakeAddressDeposit: stakeAddressDeposit,
            stakePoolDeposit: stakePoolDeposit,
            stakePoolTargetNum: stakePoolTargetNum,
            treasuryCut: treasuryCut,
            txFeeFixed: txFeeFixed,
            txFeePerByte: txFeePerByte,
            utxoCostPerByte: utxoCostPerByte
        )
    }

    // MARK: - JSONSerializable (Serializable requirement)

    public static func fromDict(_ primitive: Primitive) throws -> Self {
        let jsonAny = try primitiveToJSONAny(primitive)
        let jsonData = try JSONSerialization.data(withJSONObject: jsonAny, options: [.sortedKeys])
        return try JSONDecoder().decode(Self.self, from: jsonData)
    }

    public func toDict() throws -> Primitive {
        let jsonData = try JSONEncoder().encode(self)
        let jsonAny = try JSONSerialization.jsonObject(with: jsonData)
        guard case .orderedDict(var dict) = try Self.jsonAnyToPrimitive(jsonAny) else {
            throw CardanoCoreError.valueError("ProtocolParameters JSON must be an object")
        }
        // JSONSerialization reads a decimal into a Double, which cannot hold
        // most of them; put the rationals back exactly.
        func set(_ value: Primitive, _ path: String...) {
            func put(_ value: Primitive, _ path: ArraySlice<String>,
                     in dict: inout OrderedDictionary<Primitive, Primitive>) {
                guard let key = path.first else { return }
                if path.count == 1 {
                    dict[.string(key)] = value
                } else if case .orderedDict(var inner)? = dict[.string(key)] {
                    put(value, path.dropFirst(), in: &inner)
                    dict[.string(key)] = .orderedDict(inner)
                }
            }
            put(value, path[...], in: &dict)
        }
        set(monetaryExpansion.jsonPrimitive, "monetaryExpansion")
        set(treasuryCut.jsonPrimitive, "treasuryCut")
        set(poolPledgeInfluence.jsonPrimitive, "poolPledgeInfluence")
        if let minFeeRefScriptCostPerByte {
            set(minFeeRefScriptCostPerByte.jsonPrimitive, "minFeeRefScriptCostPerByte")
        }
        set(executionUnitPrices.priceMemory.jsonPrimitive, "executionUnitPrices", "priceMemory")
        set(executionUnitPrices.priceSteps.jsonPrimitive, "executionUnitPrices", "priceSteps")
        for (key, value) in poolVotingThresholds.namedValues {
            set(value.jsonPrimitive, "poolVotingThresholds", key)
        }
        for (key, value) in dRepVotingThresholds.namedValues {
            set(value.jsonPrimitive, "dRepVotingThresholds", key)
        }
        if let base = minFeeReferenceScripts?.base {
            set(base.jsonPrimitive, "minFeeReferenceScripts", "base")
        }
        if let multiplier = minFeeReferenceScripts?.multiplier {
            set(multiplier.jsonPrimitive, "minFeeReferenceScripts", "multiplier")
        }
        return .orderedDict(dict)
    }

    // MARK: - Private JSON ↔ Primitive helpers

    /// Extract raw [Int] cost model arrays without template validation.
    /// The n2c format sends raw integer arrays; template-based validation belongs
    /// in higher-level tooling, not wire decoding.
    private static func decodeCostModelsRaw(_ primitive: Primitive) throws -> ProtocolParametersCostModels {
        let pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d):         pairs = d.map { ($0.key, $0.value) }
        case .orderedDict(let od): pairs = od.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Cost models must be a CBOR map")
        }
        var raw = [Int: [Int64]]()
        for (k, v) in pairs {
            // The CDDL keys cost models by language, `0 .. 255`.
            let key = Int(try k.integer("cost model language", as: UInt8.self))
            raw[key] = try costModelInts(v)
        }
        return ProtocolParametersCostModels(
            PlutusV1: raw[0] ?? [], PlutusV2: raw[1] ?? [], PlutusV3: raw[2] ?? [])
    }

    private static func costModelInts(_ primitive: Primitive) throws -> [Int64] {
        let items: [Primitive]
        switch primitive {
        case .list(let arr):
            items = arr
        case .indefiniteList(let indef):
            items = indef.getAll()
        case .bytes(let data):
            // PlutusV1 in n2c is wrapped in a byte string containing nested CBOR.
            let nested = try Primitive.from(cbor: CBORDecoder().decode(CBOR.self, from: data))
            return try costModelInts(nested)
        default:
            throw CardanoCoreError.deserializeError("Invalid cost model value: \(primitive)")
        }
        return try items.map { p throws -> Int64 in
            try p.integer("cost model value", as: Int64.self)
        }
    }

    private static func primitiveToJSONAny(_ primitive: Primitive) throws -> Any {
        switch primitive {
        case .string(let s):   return s
        case .int(let i):      return i
        case .uint(let u):     return Int64(exactly: u).map { $0 as Any } ?? u
        // A Double as the shortest decimal that reads back to it: what was
        // meant by 0.0577, where JSONSerialization would write 17 digits.
        case .float(let f):    return f.isFinite ? NSDecimalNumber(string: "\(f)") : f
        // Written as its exact digits.
        case .decimal(let d):  return NSDecimalNumber(decimal: d)
        case .bool(let b):     return b
        case .null:            return NSNull()
        case .list(let arr):   return try arr.map { try primitiveToJSONAny($0) }
        case .orderedDict(let d):
            var result: [String: Any] = [:]
            for (k, v) in d {
                if case .string(let s) = k { result[s] = try primitiveToJSONAny(v) }
            }
            return result
        case .dict(let d):
            var result: [String: Any] = [:]
            for (k, v) in d {
                if case .string(let s) = k { result[s] = try primitiveToJSONAny(v) }
            }
            return result
        default:
            throw CardanoCoreError.valueError("Unsupported Primitive for JSON conversion: \(primitive)")
        }
    }

    private static func jsonAnyToPrimitive(_ value: Any) throws -> Primitive {
        switch value {
        case let s as String:  return .string(s)
        case let i as Int:     return .int(Int64(i))
        case let i as Int64:   return .int(i)
        // A coin above Int64.max, which JSONSerialization reads as an
        // unsigned NSNumber.
        case let u as UInt64:  return .uint(u)
        // A number with more digits than a Double holds, read exactly.
        case let d as NSDecimalNumber: return .decimal(d.decimalValue)
        case let f as Double:  return .float(f)
        case let b as Bool:    return .bool(b)
        case let arr as [Any]: return .list(try arr.map { try jsonAnyToPrimitive($0) })
        case let dict as [String: Any]:
            var result: OrderedDictionary<Primitive, Primitive> = [:]
            for k in dict.keys.sorted() {
                result[.string(k)] = try jsonAnyToPrimitive(dict[k]!)
            }
            return .orderedDict(result)
        case is NSNull:        return .null
        default:
            throw CardanoCoreError.valueError("Unsupported type for Primitive conversion: \(type(of: value))")
        }
    }
}

// MARK: - Supporting types

public struct ProtocolParametersCostModels: Codable, Equatable, Hashable, Sendable {
    public let PlutusV1: [Int64]
    public let PlutusV2: [Int64]
    public let PlutusV3: [Int64]

    public init(PlutusV1: [Int64], PlutusV2: [Int64], PlutusV3: [Int64]) {
        self.PlutusV1 = PlutusV1
        self.PlutusV2 = PlutusV2
        self.PlutusV3 = PlutusV3
    }

    public func getVersion(_ version: Int) -> [Int64]? {
        switch version {
            case 1: return PlutusV1
            case 2: return PlutusV2
            case 3: return PlutusV3
            default: return nil
        }
    }
}

/// The DRep voting thresholds: each a `UnitInterval`, held exactly.
public struct DRepVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let committeeNoConfidence: UnitInterval
    public let committeeNormal: UnitInterval
    public let hardForkInitiation: UnitInterval
    public let motionNoConfidence: UnitInterval
    public let ppEconomicGroup: UnitInterval
    public let ppGovGroup: UnitInterval
    public let ppNetworkGroup: UnitInterval
    public let ppTechnicalGroup: UnitInterval
    public let treasuryWithdrawal: UnitInterval
    public let updateToConstitution: UnitInterval

    public init(committeeNoConfidence: UnitInterval, committeeNormal: UnitInterval, hardForkInitiation: UnitInterval,
                motionNoConfidence: UnitInterval, ppEconomicGroup: UnitInterval, ppGovGroup: UnitInterval,
                ppNetworkGroup: UnitInterval, ppTechnicalGroup: UnitInterval, treasuryWithdrawal: UnitInterval,
                updateToConstitution: UnitInterval) {
        self.committeeNoConfidence = committeeNoConfidence
        self.committeeNormal = committeeNormal
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppEconomicGroup = ppEconomicGroup
        self.ppGovGroup = ppGovGroup
        self.ppNetworkGroup = ppNetworkGroup
        self.ppTechnicalGroup = ppTechnicalGroup
        self.treasuryWithdrawal = treasuryWithdrawal
        self.updateToConstitution = updateToConstitution
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case committeeNoConfidence, committeeNormal, hardForkInitiation, motionNoConfidence, ppEconomicGroup
        case ppGovGroup, ppNetworkGroup, ppTechnicalGroup, treasuryWithdrawal, updateToConstitution
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            committeeNoConfidence: try c.decodeUnitInterval(forKey: .committeeNoConfidence),
            committeeNormal: try c.decodeUnitInterval(forKey: .committeeNormal),
            hardForkInitiation: try c.decodeUnitInterval(forKey: .hardForkInitiation),
            motionNoConfidence: try c.decodeUnitInterval(forKey: .motionNoConfidence),
            ppEconomicGroup: try c.decodeUnitInterval(forKey: .ppEconomicGroup),
            ppGovGroup: try c.decodeUnitInterval(forKey: .ppGovGroup),
            ppNetworkGroup: try c.decodeUnitInterval(forKey: .ppNetworkGroup),
            ppTechnicalGroup: try c.decodeUnitInterval(forKey: .ppTechnicalGroup),
            treasuryWithdrawal: try c.decodeUnitInterval(forKey: .treasuryWithdrawal),
            updateToConstitution: try c.decodeUnitInterval(forKey: .updateToConstitution))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in namedValues {
            try c.encodeLedgerRational(value, forKey: CodingKeys(rawValue: key)!)
        }
    }

    /// The thresholds in the ledger's CBOR order (`drep_voting_thresholds`).
    public var ledgerOrder: [UnitInterval] {
        [motionNoConfidence, committeeNormal, committeeNoConfidence, updateToConstitution, hardForkInitiation,
         ppNetworkGroup, ppEconomicGroup, ppTechnicalGroup, ppGovGroup, treasuryWithdrawal]
    }

    var namedValues: [(String, UnitInterval)] {
        [("committeeNoConfidence", committeeNoConfidence), ("committeeNormal", committeeNormal),
         ("hardForkInitiation", hardForkInitiation), ("motionNoConfidence", motionNoConfidence),
         ("ppEconomicGroup", ppEconomicGroup), ("ppGovGroup", ppGovGroup), ("ppNetworkGroup", ppNetworkGroup),
         ("ppTechnicalGroup", ppTechnicalGroup), ("treasuryWithdrawal", treasuryWithdrawal),
         ("updateToConstitution", updateToConstitution)]
    }

    /// Reads the ledger's `drep_voting_thresholds`: ten `#6.30` unit
    /// intervals in its order.
    init(cbor primitive: Primitive) throws {
        guard case .list(let t) = primitive, t.count == 10 else {
            throw CardanoCoreError.deserializeError("dRepVotingThresholds must be a list of 10 unit intervals")
        }
        func at(_ i: Int) throws -> UnitInterval { try UnitInterval.ledgerCBOR(t[i], "dRepVotingThresholds[\(i)]") }
        self.init(
            committeeNoConfidence: try at(2), committeeNormal: try at(1), hardForkInitiation: try at(4),
            motionNoConfidence: try at(0), ppEconomicGroup: try at(6), ppGovGroup: try at(8),
            ppNetworkGroup: try at(5), ppTechnicalGroup: try at(7), treasuryWithdrawal: try at(9),
            updateToConstitution: try at(3))
    }

    /// The thresholds as the ledger writes them.
    ///
    /// - Throws: When a threshold is above one.
    func ledgerPrimitive() throws -> Primitive {
        .list(try ledgerOrder.enumerated().map { i, value in
            try LedgerRational.check(value.numerator, value.denominator, .unitInterval, "dRepVotingThresholds[\(i)]")
            return value.ledgerPrimitive()
        })
    }
}

/// The reference-script fee constants as some providers report them. The
/// ledger fixes them in Conway; Dijkstra makes them parameters.
public struct MinReferenceScriptsSize: Codable, Equatable, Hashable, Sendable {
    /// Lovelace per byte: the `minFeeRefScriptCostPerByte` `NonNegativeInterval`.
    public let base: NonNegativeInterval?
    /// The cost growth per stride: a `PositiveInterval` (1.2 in Conway).
    public let multiplier: NonNegativeInterval?
    /// The stride in bytes: a `NonZero Word32` (25600 in Conway).
    public let range: UInt32?

    public init(base: NonNegativeInterval?, multiplier: NonNegativeInterval?, range: UInt32?) {
        self.base = base
        self.multiplier = multiplier
        self.range = range
    }

    private enum CodingKeys: String, CodingKey { case base, multiplier, range }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = try c.decodeNonNegativeIntervalIfPresent(forKey: .base)
        multiplier = try c.decodeNonNegativeIntervalIfPresent(forKey: .multiplier, bounds: .positiveInterval)
        range = try c.decodeIfPresent(UInt32.self, forKey: .range)
        if range == 0 {
            throw CardanoCoreError.deserializeError("minFeeReferenceScripts range: must not be zero")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLedgerRationalIfPresent(base, forKey: .base)
        try c.encodeLedgerRationalIfPresent(multiplier, forKey: .multiplier)
        try c.encodeIfPresent(range, forKey: .range)
    }
}

/// The prices of execution units: the ledger's `Prices`, each a
/// `NonNegativeInterval`, held exactly.
public struct ExecutionUnitPrices: Codable, Equatable, Hashable, Sendable {
    public let priceMemory: NonNegativeInterval
    public let priceSteps: NonNegativeInterval

    public init(priceMemory: NonNegativeInterval, priceSteps: NonNegativeInterval) {
        self.priceMemory = priceMemory
        self.priceSteps = priceSteps
    }

    private enum CodingKeys: String, CodingKey { case priceMemory, priceSteps, prMem, prSteps }

    /// Reads `priceMemory`/`priceSteps`, or the older `prMem`/`prSteps`, as
    /// the ledger's `FromJSON Prices` does; each a decimal or a fraction.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        priceMemory = try c.contains(.priceMemory)
            ? c.decodeNonNegativeInterval(forKey: .priceMemory) : c.decodeNonNegativeInterval(forKey: .prMem)
        priceSteps = try c.contains(.priceSteps)
            ? c.decodeNonNegativeInterval(forKey: .priceSteps) : c.decodeNonNegativeInterval(forKey: .prSteps)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLedgerRational(priceMemory, forKey: .priceMemory)
        try c.encodeLedgerRational(priceSteps, forKey: .priceSteps)
    }

    /// The fee for a script that uses `exUnits`, as the ledger computes it
    /// (`txscriptfee`): `ceiling (mem × priceMemory + steps × priceSteps)`,
    /// in exact rational arithmetic.
    ///
    /// - Throws: When the fee does not fit a `Coin`.
    public func scriptFee(memory: UInt64, steps: UInt64) throws -> Coin {
        let memNum = BigUInt(memory) * BigUInt(priceMemory.numerator)
        let stepNum = BigUInt(steps) * BigUInt(priceSteps.numerator)
        let memDen = BigUInt(priceMemory.denominator), stepDen = BigUInt(priceSteps.denominator)
        guard memDen > 0, stepDen > 0 else {
            throw CardanoCoreError.valueError("ExecutionUnitPrices: a price has a zero denominator")
        }
        let numerator = memNum * stepDen + stepNum * memDen
        let denominator = memDen * stepDen
        let (quotient, remainder) = numerator.quotientAndRemainder(dividingBy: denominator)
        let fee = remainder == 0 ? quotient : quotient + 1
        guard let coin = Coin(exactly: fee) else {
            throw CardanoCoreError.valueError("ExecutionUnitPrices: the fee \(fee) does not fit a Coin")
        }
        return coin
    }

    /// Reads the ledger's `ex_unit_prices`: `[mem_price, step_price]`, each a
    /// `#6.30` non-negative interval.
    init(cbor primitive: Primitive, _ what: String) throws {
        guard case .list(let prices) = primitive, prices.count == 2 else {
            throw CardanoCoreError.deserializeError("\(what): expected [memPrice, stepPrice]")
        }
        self.init(priceMemory: try NonNegativeInterval.ledgerCBOR(prices[0], "\(what) memPrice"),
                  priceSteps: try NonNegativeInterval.ledgerCBOR(prices[1], "\(what) stepPrice"))
    }

    /// The prices as the ledger writes them: `[mem_price, step_price]`.
    func ledgerPrimitive() throws -> Primitive {
        try LedgerRational.check(priceMemory.numerator, priceMemory.denominator, .nonNegativeInterval, "priceMemory")
        try LedgerRational.check(priceSteps.numerator, priceSteps.denominator, .nonNegativeInterval, "priceSteps")
        return .list([priceMemory.ledgerPrimitive(), priceSteps.ledgerPrimitive()])
    }
}

public struct ProtocolParametersExecutionUnits: Codable, Equatable, Hashable, Sendable {
    /// `Natural` in the ledger; its JSON reader accepts the full `Word64`
    /// range, its CBOR reader nothing above `Int64.max`.
    public let memory: UInt64
    public let steps: UInt64

    public init(memory: UInt64, steps: UInt64) {
        self.memory = memory
        self.steps = steps
    }
}

/// The stake pool voting thresholds: each a `UnitInterval`, held exactly.
public struct ProtocolParametersPoolVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let committeeNoConfidence: UnitInterval
    public let committeeNormal: UnitInterval
    public let hardForkInitiation: UnitInterval
    public let motionNoConfidence: UnitInterval
    public let ppSecurityGroup: UnitInterval

    public init(committeeNoConfidence: UnitInterval, committeeNormal: UnitInterval, hardForkInitiation: UnitInterval,
                motionNoConfidence: UnitInterval, ppSecurityGroup: UnitInterval) {
        self.committeeNoConfidence = committeeNoConfidence
        self.committeeNormal = committeeNormal
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppSecurityGroup = ppSecurityGroup
    }

    private enum CodingKeys: String, CodingKey {
        case committeeNoConfidence, committeeNormal, hardForkInitiation, motionNoConfidence, ppSecurityGroup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            committeeNoConfidence: try c.decodeUnitInterval(forKey: .committeeNoConfidence),
            committeeNormal: try c.decodeUnitInterval(forKey: .committeeNormal),
            hardForkInitiation: try c.decodeUnitInterval(forKey: .hardForkInitiation),
            motionNoConfidence: try c.decodeUnitInterval(forKey: .motionNoConfidence),
            ppSecurityGroup: try c.decodeUnitInterval(forKey: .ppSecurityGroup))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in namedValues {
            try c.encodeLedgerRational(value, forKey: CodingKeys(rawValue: key)!)
        }
    }

    /// The thresholds in the ledger's CBOR order (`pool_voting_thresholds`):
    /// motion of no confidence, committee normal, committee no confidence,
    /// hard fork initiation, security group.
    public var ledgerOrder: [UnitInterval] {
        [motionNoConfidence, committeeNormal, committeeNoConfidence, hardForkInitiation, ppSecurityGroup]
    }

    var namedValues: [(String, UnitInterval)] {
        [("committeeNoConfidence", committeeNoConfidence), ("committeeNormal", committeeNormal),
         ("hardForkInitiation", hardForkInitiation), ("motionNoConfidence", motionNoConfidence),
         ("ppSecurityGroup", ppSecurityGroup)]
    }

    /// Reads the ledger's `pool_voting_thresholds`: five `#6.30` unit
    /// intervals in its order.
    init(cbor primitive: Primitive) throws {
        guard case .list(let t) = primitive, t.count == 5 else {
            throw CardanoCoreError.deserializeError("poolVotingThresholds must be a list of 5 unit intervals")
        }
        func at(_ i: Int) throws -> UnitInterval { try UnitInterval.ledgerCBOR(t[i], "poolVotingThresholds[\(i)]") }
        self.init(committeeNoConfidence: try at(2), committeeNormal: try at(1), hardForkInitiation: try at(3),
                  motionNoConfidence: try at(0), ppSecurityGroup: try at(4))
    }

    /// The thresholds as the ledger writes them.
    ///
    /// - Throws: When a threshold is above one.
    func ledgerPrimitive() throws -> Primitive {
        .list(try ledgerOrder.enumerated().map { i, value in
            try LedgerRational.check(value.numerator, value.denominator, .unitInterval, "poolVotingThresholds[\(i)]")
            return value.ledgerPrimitive()
        })
    }
}

/// `ProtVer` in the ledger: a `Version` (a `Word32`) and a `Word32` minor.
public struct ProtocolParametersProtocolVersion: Codable, Equatable, Hashable, Sendable {
    public let major: UInt32
    public let minor: UInt32

    public init(major: UInt32, minor: UInt32) {
        self.major = major
        self.minor = minor
    }
}
