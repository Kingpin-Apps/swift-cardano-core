import Foundation
import OrderedCollections
import PotentCBOR

public let ALONZO_COINS_PER_UTXO_WORD = 34482

// MARK: - Fraction helpers (Conway CBOR ↔ Double)

private func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 {
    b == 0 ? a : gcd(b, a % b)
}

internal func doubleToUnitInterval(_ value: Double, precision: UInt64 = 1_000_000_000) -> UnitInterval? {
    guard value >= 0, value <= 1 else { return nil }
    let num = UInt64((value * Double(precision)).rounded())
    let g = gcd(num, precision)
    return UnitInterval(numerator: num / g, denominator: precision / g)
}

internal func doubleToNonNegativeInterval(_ value: Double, precision: UInt64 = 1_000_000_000) -> NonNegativeInterval? {
    guard value >= 0 else { return nil }
    let num = UInt64((value * Double(precision)).rounded())
    let g = gcd(num, precision)
    return NonNegativeInterval(lowerBound: UInt(num / g), upperBound: precision / g)
}

extension UnitInterval {
    internal var toDouble: Double { Double(numerator) / Double(denominator) }
}

extension NonNegativeInterval {
    internal var toDouble: Double {
        guard upperBound > 0 else { return 0 }
        return Double(lowerBound) / Double(upperBound)
    }
}

// MARK: - ProtocolParameters

public struct ProtocolParameters: Serializable, JSONLoadable {
    public let collateralPercentage: Int

    private var _coinsPerUtxoWord: Int?
    public var coinsPerUtxoWord: Int {
        get {
            if let coinsPerUtxoWord = _coinsPerUtxoWord {
                return coinsPerUtxoWord
            } else {
                return ALONZO_COINS_PER_UTXO_WORD
            }
        }
        set {
            _coinsPerUtxoWord = newValue
        }
    }

    public let committeeMaxTermLength: Int
    public let committeeMinSize: Int
    public let costModels: ProtocolParametersCostModels
    public let dRepActivity: Int
    public let dRepDeposit: Int
    public let dRepVotingThresholds: DRepVotingThresholds
    public let executionUnitPrices: ExecutionUnitPrices
    public let govActionDeposit: Int
    public let govActionLifetime: Int
    public let maxBlockBodySize: Int
    public let maxBlockExecutionUnits: ProtocolParametersExecutionUnits
    public let maxBlockHeaderSize: Int
    public let maxCollateralInputs: Int
    public let maxTxExecutionUnits: ProtocolParametersExecutionUnits
    public let maxTxSize: Int
    public let maxValueSize: Int
    public let maxReferenceScriptsSize: Int?
    public let minFeeReferenceScripts: MinReferenceScriptsSize?
    public let minFeeRefScriptCostPerByte: Int?
    public let minPoolCost: Int
    public let monetaryExpansion: Double
    public let poolPledgeInfluence: Double
    public let poolRetireMaxEpoch: Int
    public let poolVotingThresholds: ProtocolParametersPoolVotingThresholds
    public let protocolVersion: ProtocolParametersProtocolVersion
    public let stakeAddressDeposit: Int
    public let stakePoolDeposit: Int
    public let stakePoolTargetNum: Int
    public let treasuryCut: Double
    public let txFeeFixed: Int
    public let txFeePerByte: Int
    public let utxoCostPerByte: Int

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

    public init(collateralPercentage: Int,
                coinsPerUtxoWord: Int? = nil,
                committeeMaxTermLength: Int,
                committeeMinSize: Int,
                costModels: ProtocolParametersCostModels,
                dRepActivity: Int,
                dRepDeposit: Int,
                dRepVotingThresholds: DRepVotingThresholds,
                executionUnitPrices: ExecutionUnitPrices,
                govActionDeposit: Int,
                govActionLifetime: Int,
                maxBlockBodySize: Int,
                maxBlockExecutionUnits: ProtocolParametersExecutionUnits,
                maxBlockHeaderSize: Int,
                maxCollateralInputs: Int,
                maxTxExecutionUnits: ProtocolParametersExecutionUnits,
                maxTxSize: Int,
                maxValueSize: Int,
                maxReferenceScriptsSize: Int? = nil,
                minFeeReferenceScripts: MinReferenceScriptsSize? = nil,
                minFeeRefScriptCostPerByte: Int? = nil,
                minPoolCost: Int,
                monetaryExpansion: Double,
                poolPledgeInfluence: Double,
                poolRetireMaxEpoch: Int,
                poolVotingThresholds: ProtocolParametersPoolVotingThresholds,
                protocolVersion: ProtocolParametersProtocolVersion,
                stakeAddressDeposit: Int,
                stakePoolDeposit: Int,
                stakePoolTargetNum: Int,
                treasuryCut: Double,
                txFeeFixed: Int,
                txFeePerByte: Int,
                utxoCostPerByte: Int
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
            let collateralPercentage    = try c.decode(Int.self, forKey: .collateralPercentage)
            let coinsPerUtxoWord        = try c.decodeIfPresent(Int.self, forKey: .coinsPerUtxoWord)
            let committeeMaxTermLength  = try c.decode(Int.self, forKey: .committeeMaxTermLength)
            let committeeMinSize        = try c.decode(Int.self, forKey: .committeeMinSize)
            let costModels              = try c.decode(ProtocolParametersCostModels.self, forKey: .costModels)
            let dRepActivity            = try c.decode(Int.self, forKey: .dRepActivity)
            let dRepDeposit             = try c.decode(Int.self, forKey: .dRepDeposit)
            let dRepVotingThresholds    = try c.decode(DRepVotingThresholds.self, forKey: .dRepVotingThresholds)
            let executionUnitPrices     = try c.decode(ExecutionUnitPrices.self, forKey: .executionUnitPrices)
            let govActionDeposit        = try c.decode(Int.self, forKey: .govActionDeposit)
            let govActionLifetime       = try c.decode(Int.self, forKey: .govActionLifetime)
            let maxBlockBodySize        = try c.decode(Int.self, forKey: .maxBlockBodySize)
            let maxBlockExecutionUnits  = try c.decode(ProtocolParametersExecutionUnits.self, forKey: .maxBlockExecutionUnits)
            let maxBlockHeaderSize      = try c.decode(Int.self, forKey: .maxBlockHeaderSize)
            let maxCollateralInputs     = try c.decode(Int.self, forKey: .maxCollateralInputs)
            let maxTxExecutionUnits     = try c.decode(ProtocolParametersExecutionUnits.self, forKey: .maxTxExecutionUnits)
            let maxTxSize               = try c.decode(Int.self, forKey: .maxTxSize)
            let maxValueSize            = try c.decode(Int.self, forKey: .maxValueSize)
            let maxReferenceScriptsSize     = try c.decodeIfPresent(Int.self, forKey: .maxReferenceScriptsSize)
            let minFeeReferenceScripts      = try c.decodeIfPresent(MinReferenceScriptsSize.self, forKey: .minFeeReferenceScripts)
            let minFeeRefScriptCostPerByte  = try c.decodeIfPresent(Int.self, forKey: .minFeeRefScriptCostPerByte)
            let minPoolCost             = try c.decode(Int.self, forKey: .minPoolCost)
            let monetaryExpansion       = try c.decode(Double.self, forKey: .monetaryExpansion)
            let poolPledgeInfluence     = try c.decode(Double.self, forKey: .poolPledgeInfluence)
            let poolRetireMaxEpoch      = try c.decode(Int.self, forKey: .poolRetireMaxEpoch)
            let poolVotingThresholds    = try c.decode(ProtocolParametersPoolVotingThresholds.self, forKey: .poolVotingThresholds)
            let protocolVersion         = try c.decode(ProtocolParametersProtocolVersion.self, forKey: .protocolVersion)
            let stakeAddressDeposit     = try c.decode(Int.self, forKey: .stakeAddressDeposit)
            let stakePoolDeposit        = try c.decode(Int.self, forKey: .stakePoolDeposit)
            let stakePoolTargetNum      = try c.decode(Int.self, forKey: .stakePoolTargetNum)
            let treasuryCut             = try c.decode(Double.self, forKey: .treasuryCut)
            let txFeeFixed              = try c.decode(Int.self, forKey: .txFeeFixed)
            let txFeePerByte            = try c.decode(Int.self, forKey: .txFeePerByte)
            let utxoCostPerByte         = try c.decode(Int.self, forKey: .utxoCostPerByte)
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
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
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
            try c.encodeIfPresent(minFeeRefScriptCostPerByte, forKey: .minFeeRefScriptCostPerByte)
            try c.encode(minPoolCost, forKey: .minPoolCost)
            try c.encode(monetaryExpansion, forKey: .monetaryExpansion)
            try c.encode(poolPledgeInfluence, forKey: .poolPledgeInfluence)
            try c.encode(poolRetireMaxEpoch, forKey: .poolRetireMaxEpoch)
            try c.encode(poolVotingThresholds, forKey: .poolVotingThresholds)
            try c.encode(protocolVersion, forKey: .protocolVersion)
            try c.encode(stakeAddressDeposit, forKey: .stakeAddressDeposit)
            try c.encode(stakePoolDeposit, forKey: .stakePoolDeposit)
            try c.encode(stakePoolTargetNum, forKey: .stakePoolTargetNum)
            try c.encode(treasuryCut, forKey: .treasuryCut)
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
    enum CBORKey: Int {
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

        var map = [Int: Primitive]()
        for (k, v) in pairs {
            switch k {
            case .int(let n):  map[n] = v
            case .uint(let n): map[Int(n)] = v
            default:
                throw CardanoCoreError.deserializeError("ProtocolParameters CBOR key must be integer")
            }
        }

        func intVal(_ key: CBORKey) throws -> Int {
            guard let p = map[key.rawValue] else {
                throw CardanoCoreError.deserializeError("Missing CBOR key \(key.rawValue)")
            }
            switch p {
            case .int(let v):  return v
            case .uint(let v): return Int(v)
            default:
                throw CardanoCoreError.deserializeError("Expected int at CBOR key \(key.rawValue)")
            }
        }

        func require(_ key: CBORKey) throws -> Primitive {
            guard let p = map[key.rawValue] else {
                throw CardanoCoreError.deserializeError("Missing CBOR key \(key.rawValue)")
            }
            return p
        }

        let txFeePerByte        = try intVal(.minFeeA)
        let txFeeFixed          = try intVal(.minFeeB)
        let maxBlockBodySize    = try intVal(.maxBlockBodySize)
        let maxTxSize           = try intVal(.maxTxSize)
        let maxBlockHeaderSize  = try intVal(.maxBlockHeaderSize)
        let stakeAddressDeposit = try intVal(.keyDeposit)
        let stakePoolDeposit    = try intVal(.poolDeposit)
        let poolRetireMaxEpoch  = try intVal(.maximumEpoch)
        let stakePoolTargetNum  = try intVal(.nOpt)

        let poolPledgeInfluence = try NonNegativeInterval(from: require(.poolPledgeInfluence)).toDouble
        let monetaryExpansion   = try UnitInterval(from: require(.expansionRate)).toDouble
        let treasuryCut         = try UnitInterval(from: require(.treasuryGrowthRate)).toDouble

        let pv = try ProtocolVersion(from: require(.protocolVersion))
        let protocolVersion = ProtocolParametersProtocolVersion(major: pv.major ?? 0, minor: pv.minor ?? 0)

        let minPoolCost     = try intVal(.minPoolCost)
        let utxoCostPerByte = try intVal(.adaPerUtxoByte)

        let cborCM = try CostModels(from: require(.costModels))
        let costModels = ProtocolParametersCostModels(
            PlutusV1: cborCM.plutusV1.map { Array($0.values) } ?? [],
            PlutusV2: cborCM.plutusV2.map { Array($0.values) } ?? [],
            PlutusV3: cborCM.plutusV3.map { Array($0.values) } ?? []
        )

        let prices = try ExUnitPrices(from: require(.executionCosts))
        let executionUnitPrices = ExecutionUnitPrices(
            priceMemory: prices.memPrice.toDouble,
            priceSteps:  prices.stepPrice.toDouble
        )

        let txU = try ExUnits(from: require(.maxTxExUnits))
        let maxTxExecutionUnits = ProtocolParametersExecutionUnits(
            memory: Int(txU.mem), steps: Int64(txU.steps)
        )
        let blkU = try ExUnits(from: require(.maxBlockExUnits))
        let maxBlockExecutionUnits = ProtocolParametersExecutionUnits(
            memory: Int(blkU.mem), steps: Int64(blkU.steps)
        )

        let maxValueSize         = try intVal(.maxValueSize)
        let collateralPercentage = try intVal(.collateralPercentage)
        let maxCollateralInputs  = try intVal(.maxCollateralInputs)

        let pvtCBOR = try PoolVotingThresholds(from: require(.poolVotingThresholds))
        let poolVotingThresholds = ProtocolParametersPoolVotingThresholds(
            committeeNoConfidence: pvtCBOR.committeeNoConfidence?.toDouble ?? 0,
            committeeNormal:       pvtCBOR.committeeNormal?.toDouble ?? 0,
            hardForkInitiation:    pvtCBOR.hardForkInitiation?.toDouble ?? 0,
            motionNoConfidence:    pvtCBOR.motionNoConfidence?.toDouble ?? 0,
            ppSecurityGroup:       pvtCBOR.ppSecurityGroup?.toDouble ?? 0
        )

        let dvtCBOR = try DrepVotingThresholds(from: require(.drepVotingThresholds))
        guard dvtCBOR.thresholds.count == 10 else {
            throw CardanoCoreError.deserializeError("dRepVotingThresholds must have 10 elements")
        }
        let dRepVotingThresholds = DRepVotingThresholds(
            committeeNoConfidence: dvtCBOR.thresholds[2].toDouble,
            committeeNormal:       dvtCBOR.thresholds[1].toDouble,
            hardForkInitiation:    dvtCBOR.thresholds[4].toDouble,
            motionNoConfidence:    dvtCBOR.thresholds[0].toDouble,
            ppEconomicGroup:       dvtCBOR.thresholds[6].toDouble,
            ppGovGroup:            dvtCBOR.thresholds[8].toDouble,
            ppNetworkGroup:        dvtCBOR.thresholds[5].toDouble,
            ppTechnicalGroup:      dvtCBOR.thresholds[7].toDouble,
            treasuryWithdrawal:    dvtCBOR.thresholds[9].toDouble,
            updateToConstitution:  dvtCBOR.thresholds[3].toDouble
        )

        let committeeMinSize       = try intVal(.minCommitteeSize)
        let committeeMaxTermLength = try intVal(.committeeTermLimit)
        let govActionLifetime      = try intVal(.govActionValidityPeriod)
        let govActionDeposit       = try intVal(.govActionDeposit)
        let dRepDeposit            = try intVal(.drepDeposit)
        let dRepActivity           = try intVal(.drepInactivityPeriod)

        let minFeeRefScriptCostPerByte: Int?
        if let p = map[CBORKey.minFeeRefScriptCoinsPerByte.rawValue] {
            minFeeRefScriptCostPerByte = Int((try NonNegativeInterval(from: p)).lowerBound)
        } else {
            minFeeRefScriptCostPerByte = nil
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

        dict[.int(CBORKey.minFeeA.rawValue)]          = .int(txFeePerByte)
        dict[.int(CBORKey.minFeeB.rawValue)]          = .int(txFeeFixed)
        dict[.int(CBORKey.maxBlockBodySize.rawValue)]  = .int(maxBlockBodySize)
        dict[.int(CBORKey.maxTxSize.rawValue)]         = .int(maxTxSize)
        dict[.int(CBORKey.maxBlockHeaderSize.rawValue)] = .int(maxBlockHeaderSize)
        dict[.int(CBORKey.keyDeposit.rawValue)]        = .int(stakeAddressDeposit)
        dict[.int(CBORKey.poolDeposit.rawValue)]       = .int(stakePoolDeposit)
        dict[.int(CBORKey.maximumEpoch.rawValue)]      = .int(poolRetireMaxEpoch)
        dict[.int(CBORKey.nOpt.rawValue)]              = .int(stakePoolTargetNum)

        if let v = doubleToNonNegativeInterval(poolPledgeInfluence) {
            dict[.int(CBORKey.poolPledgeInfluence.rawValue)] = try v.toPrimitive()
        }
        if let v = doubleToUnitInterval(monetaryExpansion) {
            dict[.int(CBORKey.expansionRate.rawValue)] = try v.toPrimitive()
        }
        if let v = doubleToUnitInterval(treasuryCut) {
            dict[.int(CBORKey.treasuryGrowthRate.rawValue)] = try v.toPrimitive()
        }

        dict[.int(CBORKey.protocolVersion.rawValue)] = try ProtocolVersion(
            major: protocolVersion.major, minor: protocolVersion.minor
        ).toPrimitive()

        dict[.int(CBORKey.minPoolCost.rawValue)]    = .int(minPoolCost)
        dict[.int(CBORKey.adaPerUtxoByte.rawValue)] = .int(utxoCostPerByte)

        let cborCM = try CostModels([
            0: costModels.PlutusV1, 1: costModels.PlutusV2, 2: costModels.PlutusV3
        ])
        dict[.int(CBORKey.costModels.rawValue)] = try cborCM.toPrimitive()

        if let mem  = doubleToNonNegativeInterval(executionUnitPrices.priceMemory),
           let step = doubleToNonNegativeInterval(executionUnitPrices.priceSteps) {
            dict[.int(CBORKey.executionCosts.rawValue)] = try ExUnitPrices(
                memPrice: mem, stepPrice: step
            ).toPrimitive()
        }

        dict[.int(CBORKey.maxTxExUnits.rawValue)] = try ExUnits(
            mem: UInt(maxTxExecutionUnits.memory), steps: UInt(maxTxExecutionUnits.steps)
        ).toPrimitive()
        dict[.int(CBORKey.maxBlockExUnits.rawValue)] = try ExUnits(
            mem: UInt(maxBlockExecutionUnits.memory), steps: UInt(maxBlockExecutionUnits.steps)
        ).toPrimitive()

        dict[.int(CBORKey.maxValueSize.rawValue)]         = .int(maxValueSize)
        dict[.int(CBORKey.collateralPercentage.rawValue)]  = .int(collateralPercentage)
        dict[.int(CBORKey.maxCollateralInputs.rawValue)]   = .int(maxCollateralInputs)

        let pvt = poolVotingThresholds
        if let cnc = doubleToUnitInterval(pvt.committeeNoConfidence),
           let cn  = doubleToUnitInterval(pvt.committeeNormal),
           let hfi = doubleToUnitInterval(pvt.hardForkInitiation),
           let mnc = doubleToUnitInterval(pvt.motionNoConfidence),
           let psg = doubleToUnitInterval(pvt.ppSecurityGroup) {
            dict[.int(CBORKey.poolVotingThresholds.rawValue)] = try PoolVotingThresholds(
                committeeNoConfidence: cnc, committeeNormal: cn,
                hardForkInitiation: hfi, motionNoConfidence: mnc, ppSecurityGroup: psg
            ).toPrimitive()
        }

        let dvt = dRepVotingThresholds
        let dvtIntervals = [
            dvt.motionNoConfidence,  dvt.committeeNormal,  dvt.committeeNoConfidence,
            dvt.updateToConstitution, dvt.hardForkInitiation, dvt.ppNetworkGroup,
            dvt.ppEconomicGroup, dvt.ppTechnicalGroup, dvt.ppGovGroup, dvt.treasuryWithdrawal
        ].compactMap { doubleToUnitInterval($0) }
        if dvtIntervals.count == 10 {
            dict[.int(CBORKey.drepVotingThresholds.rawValue)] = try DrepVotingThresholds(
                thresholds: dvtIntervals
            ).toPrimitive()
        }

        dict[.int(CBORKey.minCommitteeSize.rawValue)]       = .int(committeeMinSize)
        dict[.int(CBORKey.committeeTermLimit.rawValue)]     = .int(committeeMaxTermLength)
        dict[.int(CBORKey.govActionValidityPeriod.rawValue)] = .int(govActionLifetime)
        dict[.int(CBORKey.govActionDeposit.rawValue)]       = .int(govActionDeposit)
        dict[.int(CBORKey.drepDeposit.rawValue)]            = .int(dRepDeposit)
        dict[.int(CBORKey.drepInactivityPeriod.rawValue)]   = .int(dRepActivity)

        return .dict(dict)
    }

    // MARK: - n2c positional-array initializer

    /// Decode from the 31-element positional CBOR array emitted by the n2c protocol.
    /// Conway CDDL positional order matches CBORKey assignments, with gaps at 12, 13, 15.
    private init(fromN2CArray elements: [Primitive]) throws {
        func uint(_ idx: Int) throws -> Int {
            switch elements[idx] {
            case .uint(let v): return Int(v)
            case .int(let v):  return v
            default: throw CardanoCoreError.deserializeError(
                "Expected integer at n2c pparams position \(idx)")
            }
        }

        let txFeePerByte        = try uint(0)
        let txFeeFixed          = try uint(1)
        let maxBlockBodySize    = try uint(2)
        let maxTxSize           = try uint(3)
        let maxBlockHeaderSize  = try uint(4)
        let stakeAddressDeposit = try uint(5)
        let stakePoolDeposit    = try uint(6)
        let poolRetireMaxEpoch  = try uint(7)
        let stakePoolTargetNum  = try uint(8)

        let poolPledgeInfluence = try ProtocolParameters.rationalToDouble(elements[9])
        let monetaryExpansion   = try ProtocolParameters.rationalToDouble(elements[10])
        let treasuryCut         = try ProtocolParameters.rationalToDouble(elements[11])

        guard case .list(let pvArr) = elements[12], pvArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid protocolVersion at n2c position 12")
        }
        let pvMajor = Int(try ProtocolParameters.uintFromPrimitive(pvArr[0]))
        let pvMinor = Int(try ProtocolParameters.uintFromPrimitive(pvArr[1]))
        let protocolVersion = ProtocolParametersProtocolVersion(major: pvMajor, minor: pvMinor)

        let minPoolCost     = try uint(13)
        let utxoCostPerByte = try uint(14)

        let costModels = try ProtocolParameters.decodeCostModelsRaw(elements[15])

        guard case .list(let ecArr) = elements[16], ecArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid executionCosts at n2c position 16")
        }
        let executionUnitPrices = ExecutionUnitPrices(
            priceMemory: try ProtocolParameters.rationalToDouble(ecArr[0]),
            priceSteps:  try ProtocolParameters.rationalToDouble(ecArr[1])
        )

        guard case .list(let txExArr) = elements[17], txExArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid maxTxExUnits at n2c position 17")
        }
        let maxTxExecutionUnits = ProtocolParametersExecutionUnits(
            memory: Int(try ProtocolParameters.uintFromPrimitive(txExArr[0])),
            steps:  Int64(try ProtocolParameters.uintFromPrimitive(txExArr[1]))
        )

        guard case .list(let blkExArr) = elements[18], blkExArr.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid maxBlockExUnits at n2c position 18")
        }
        let maxBlockExecutionUnits = ProtocolParametersExecutionUnits(
            memory: Int(try ProtocolParameters.uintFromPrimitive(blkExArr[0])),
            steps:  Int64(try ProtocolParameters.uintFromPrimitive(blkExArr[1]))
        )

        let maxValueSize         = try uint(19)
        let collateralPercentage = try uint(20)
        let maxCollateralInputs  = try uint(21)

        guard case .list(let pvtArr) = elements[22], pvtArr.count == 5 else {
            throw CardanoCoreError.deserializeError("Invalid poolVotingThresholds at n2c position 22")
        }
        let poolVotingThresholds = ProtocolParametersPoolVotingThresholds(
            committeeNoConfidence: try ProtocolParameters.rationalToDouble(pvtArr[0]),
            committeeNormal:       try ProtocolParameters.rationalToDouble(pvtArr[1]),
            hardForkInitiation:    try ProtocolParameters.rationalToDouble(pvtArr[2]),
            motionNoConfidence:    try ProtocolParameters.rationalToDouble(pvtArr[3]),
            ppSecurityGroup:       try ProtocolParameters.rationalToDouble(pvtArr[4])
        )

        guard case .list(let dvtArr) = elements[23], dvtArr.count == 10 else {
            throw CardanoCoreError.deserializeError("Invalid dRepVotingThresholds at n2c position 23")
        }
        let dRepVotingThresholds = DRepVotingThresholds(
            committeeNoConfidence: try ProtocolParameters.rationalToDouble(dvtArr[2]),
            committeeNormal:       try ProtocolParameters.rationalToDouble(dvtArr[1]),
            hardForkInitiation:    try ProtocolParameters.rationalToDouble(dvtArr[4]),
            motionNoConfidence:    try ProtocolParameters.rationalToDouble(dvtArr[0]),
            ppEconomicGroup:       try ProtocolParameters.rationalToDouble(dvtArr[6]),
            ppGovGroup:            try ProtocolParameters.rationalToDouble(dvtArr[8]),
            ppNetworkGroup:        try ProtocolParameters.rationalToDouble(dvtArr[5]),
            ppTechnicalGroup:      try ProtocolParameters.rationalToDouble(dvtArr[7]),
            treasuryWithdrawal:    try ProtocolParameters.rationalToDouble(dvtArr[9]),
            updateToConstitution:  try ProtocolParameters.rationalToDouble(dvtArr[3])
        )

        let committeeMinSize       = try uint(24)
        let committeeMaxTermLength = try uint(25)
        let govActionLifetime      = try uint(26)
        let govActionDeposit       = try uint(27)
        let dRepDeposit            = try uint(28)
        let dRepActivity           = try uint(29)
        let minFeeRefScriptCostPerByte = Int(try ProtocolParameters.rationalToDouble(elements[30]))

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
        return try Self.jsonAnyToPrimitive(jsonAny)
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
        var raw = [Int: [Int]]()
        for (k, v) in pairs {
            let key: Int
            switch k {
            case .int(let n):  key = n
            case .uint(let n): key = Int(n)
            default: continue
            }
            raw[key] = try costModelInts(v)
        }
        return ProtocolParametersCostModels(
            PlutusV1: raw[0] ?? [], PlutusV2: raw[1] ?? [], PlutusV3: raw[2] ?? [])
    }

    private static func costModelInts(_ primitive: Primitive) throws -> [Int] {
        let items: [Primitive]
        switch primitive {
        case .list(let arr):
            items = arr
        case .indefiniteList(let indef):
            items = indef.getAll()
        case .bytes(let data):
            // PlutusV1 in n2c is wrapped in a byte string containing nested CBOR.
            let nested = try CBORDecoder().decode(Primitive.self, from: data)
            return try costModelInts(nested)
        default:
            throw CardanoCoreError.deserializeError("Invalid cost model value: \(primitive)")
        }
        return try items.map { p throws -> Int in
            switch p {
            case .int(let v):  return v
            case .uint(let v): return Int(v)
            default: throw CardanoCoreError.deserializeError("Non-integer in cost model: \(p)")
            }
        }
    }

    private static func rationalToDouble(_ p: Primitive) throws -> Double {
        switch p {
        case .unitInterval(let ui):
            guard ui.denominator > 0 else { return 0 }
            return Double(ui.numerator) / Double(ui.denominator)
        default:
            break
        }
        let elements: [Primitive]
        switch p {
        case .cborTag(let tagged) where tagged.tag == 30:
            guard case .list(let arr) = tagged.value else {
                throw CardanoCoreError.deserializeError("tag-30 rational value must be a list")
            }
            elements = arr
        case .list(let arr):
            elements = arr
        default:
            throw CardanoCoreError.deserializeError("Expected rational (tag-30 or list): \(p)")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Rational must have 2 elements")
        }
        let num = Double(try uintFromPrimitive(elements[0]))
        let den = Double(try uintFromPrimitive(elements[1]))
        guard den > 0 else { return 0 }
        return num / den
    }

    private static func uintFromPrimitive(_ p: Primitive) throws -> UInt {
        switch p {
        case .uint(let v): return v
        case .int(let v) where v >= 0: return UInt(v)
        default: throw CardanoCoreError.deserializeError("Expected unsigned integer, got \(p)")
        }
    }

    private static func primitiveToJSONAny(_ primitive: Primitive) throws -> Any {
        switch primitive {
        case .string(let s):   return s
        case .int(let i):      return i
        case .uint(let u):     return Int(u)
        case .float(let f):    return f
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
        case let i as Int:     return .int(i)
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
    public let PlutusV1: [Int]
    public let PlutusV2: [Int]
    public let PlutusV3: [Int]

    public init(PlutusV1: [Int], PlutusV2: [Int], PlutusV3: [Int]) {
        self.PlutusV1 = PlutusV1
        self.PlutusV2 = PlutusV2
        self.PlutusV3 = PlutusV3
    }

    public func getVersion(_ version: Int) -> [Int]? {
        switch version {
            case 1: return PlutusV1
            case 2: return PlutusV2
            case 3: return PlutusV3
            default: return nil
        }
    }
}

public struct DRepVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let committeeNoConfidence: Double
    public let committeeNormal: Double
    public let hardForkInitiation: Double
    public let motionNoConfidence: Double
    public let ppEconomicGroup: Double
    public let ppGovGroup: Double
    public let ppNetworkGroup: Double
    public let ppTechnicalGroup: Double
    public let treasuryWithdrawal: Double
    public let updateToConstitution: Double

    public init(committeeNoConfidence: Double, committeeNormal: Double, hardForkInitiation: Double, motionNoConfidence: Double, ppEconomicGroup: Double, ppGovGroup: Double, ppNetworkGroup: Double, ppTechnicalGroup: Double, treasuryWithdrawal: Double, updateToConstitution: Double) {
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
}

public struct MinReferenceScriptsSize: Codable, Equatable, Hashable, Sendable {
    public let base: Double?
    public let multiplier: Double?
    public let range: Double?

    public init(base: Double?, multiplier: Double?, range: Double?) {
        self.base = base
        self.multiplier = multiplier
        self.range = range
    }
}

public struct ExecutionUnitPrices: Codable, Equatable, Hashable, Sendable {
    public let priceMemory: Double
    public let priceSteps: Double

    public init(priceMemory: Double, priceSteps: Double) {
        self.priceMemory = priceMemory
        self.priceSteps = priceSteps
    }
}

public struct ProtocolParametersExecutionUnits: Codable, Equatable, Hashable, Sendable {
    public let memory: Int
    public let steps: Int64

    public init(memory: Int, steps: Int64) {
        self.memory = memory
        self.steps = steps
    }
}

public struct ProtocolParametersPoolVotingThresholds: Codable, Equatable, Hashable, Sendable {
    public let committeeNoConfidence: Double
    public let committeeNormal: Double
    public let hardForkInitiation: Double
    public let motionNoConfidence: Double
    public let ppSecurityGroup: Double

    public init(committeeNoConfidence: Double, committeeNormal: Double, hardForkInitiation: Double, motionNoConfidence: Double, ppSecurityGroup: Double) {
        self.committeeNoConfidence = committeeNoConfidence
        self.committeeNormal = committeeNormal
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppSecurityGroup = ppSecurityGroup
    }
}

public struct ProtocolParametersProtocolVersion: Codable, Equatable, Hashable, Sendable {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
}
