import Foundation
import OrderedCollections

public struct ParameterChangeAction: GovernanceAction {
    public static var code: GovActionCode { .parameterChangeAction }

    public var id: GovActionID?
    public let protocolParamUpdate: ProtocolParamUpdate
    public let policyHash: PolicyHash?

    public init(id: GovActionID, protocolParamUpdate: ProtocolParamUpdate, policyHash: PolicyHash?)
    {
        self.id = id
        self.protocolParamUpdate = protocolParamUpdate
        self.policyHash = policyHash
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)

        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type: \(code)")
        }

        if try container.decodeNil() {
            id = nil
        } else {
            id = try container.decode(GovActionID.self)
        }
        protocolParamUpdate = try container.decode(ProtocolParamUpdate.self)
        if try container.decodeNil() {
            policyHash = nil
        } else {
            policyHash = try container.decode(PolicyHash.self)
        }
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive,
            elements.count == 4
        else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }
        let code: Int
        switch elements[0] {
        case .int(let v) where Int(exactly: v) != nil: code = Int(v)
        case .uint(let v) where Int(exactly: v) != nil: code = Int(v)
        default: throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }

        if case .null = elements[1] {
            id = nil
        } else {
            id = try GovActionID(from: elements[1])
        }

        protocolParamUpdate = try ProtocolParamUpdate(from: elements[2])

        if case .null = elements[3] {
            policyHash = nil
        } else {
            policyHash = try PolicyHash(from: elements[3])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(protocolParamUpdate)
        try container.encode(policyHash)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
            try protocolParamUpdate.toPrimitive(),
            policyHash?.toPrimitive() ?? .null,
        ])
    }
}

// MARK: - ProtocolParamUpdate

public struct ProtocolParamUpdate: CBORSerializable, Sendable {
    public var minFeeA: Coin?
    public var minFeeB: Coin?
    public var maxBlockBodySize: UInt32?
    public var maxTransactionSize: UInt32?
    public var maxBlockHeaderSize: UInt16?

    public var keyDeposit: Coin?
    public var poolDeposit: Coin?
    public var maximumEpoch: EpochInterval?
    public var nOpt: UInt16?
    public var poolPledgeInfluence: NonNegativeInterval?

    public var expansionRate: UnitInterval?
    public var treasuryGrowthRate: UnitInterval?
    public var decentralizationConstant: UnitInterval?
    public var extraEntropy: UInt32?
    public var protocolVersion: ProtocolVersion?

    public var minPoolCost: Coin?
    public var adaPerUtxoByte: Coin?
    public var costModels: CostModels?
    public var executionCosts: ExUnitPrices?
    public var maxTxExUnits: ExUnits?
    public var maxBlockExUnits: ExUnits?
    public var maxValueSize: UInt32?
    public var collateralPercentage: UInt16?

    public var maxCollateralInputs: UInt16?
    public var poolVotingThresholds: PoolVotingThresholds?
    public var drepVotingThresholds: DrepVotingThresholds?
    public var minCommitteeSize: UInt16?
    public var committeeTermLimit: EpochInterval?

    public var governanceActionValidityPeriod: EpochInterval?
    public var governanceActionDeposit: Coin?
    public var drepDeposit: Coin?
    public var drepInactivityPeriod: EpochInterval?
    public var minFeeRefScriptCoinsPerByte: NonNegativeInterval?

    enum CodingKeys: Int, CodingKey {
        case minFeeA = 0
        case minFeeB = 1
        case maxBlockBodySize = 2
        case maxTransactionSize = 3
        case maxBlockHeaderSize = 4

        case keyDeposit = 5
        case poolDeposit = 6
        case maximumEpoch = 7
        case nOpt = 8
        case poolPledgeInfluence = 9

        case expansionRate = 10
        case treasuryGrowthRate = 11
        case decentralizationConstant = 12
        case extraEntropy = 13
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
        case governanceActionValidityPeriod = 29
        case governanceActionDeposit = 30

        case drepDeposit = 31
        case drepInactivityPeriod = 32
        case minFeeRefScriptCoinsPerByte = 33
    }

    public init(
        minFeeA: Coin? = nil,
        minFeeB: Coin? = nil,
        maxBlockBodySize: UInt32? = nil,
        maxTransactionSize: UInt32? = nil,
        maxBlockHeaderSize: UInt16? = nil,

        keyDeposit: Coin? = nil,
        poolDeposit: Coin? = nil,
        maximumEpoch: EpochInterval? = nil,
        nOpt: UInt16? = nil,
        poolPledgeInfluence: NonNegativeInterval? = nil,

        expansionRate: UnitInterval? = nil,
        treasuryGrowthRate: UnitInterval? = nil,
        decentralizationConstant: UnitInterval? = nil,
        extraEntropy: UInt32? = nil,
        protocolVersion: ProtocolVersion? = nil,

        minPoolCost: Coin? = nil,
        adaPerUtxoByte: Coin? = nil,
        costModels: CostModels? = nil,
        executionCosts: ExUnitPrices? = nil,
        maxTxExUnits: ExUnits? = nil,
        maxBlockExUnits: ExUnits? = nil,
        maxValueSize: UInt32? = nil,
        collateralPercentage: UInt16? = nil,

        maxCollateralInputs: UInt16? = nil,
        poolVotingThresholds: PoolVotingThresholds? = nil,
        drepVotingThresholds: DrepVotingThresholds? = nil,
        minCommitteeSize: UInt16? = nil,
        committeeTermLimit: EpochInterval? = nil,

        governanceActionValidityPeriod: EpochInterval? = nil,
        governanceActionDeposit: Coin? = nil,
        drepDeposit: Coin? = nil,
        drepInactivityPeriod: EpochInterval? = nil,
        minFeeRefScriptCoinsPerByte: NonNegativeInterval? = nil
    ) {
        self.minFeeA = minFeeA
        self.minFeeB = minFeeB
        self.maxBlockBodySize = maxBlockBodySize
        self.maxTransactionSize = maxTransactionSize
        self.maxBlockHeaderSize = maxBlockHeaderSize

        self.keyDeposit = keyDeposit
        self.poolDeposit = poolDeposit
        self.maximumEpoch = maximumEpoch
        self.nOpt = nOpt
        self.poolPledgeInfluence = poolPledgeInfluence

        self.expansionRate = expansionRate
        self.treasuryGrowthRate = treasuryGrowthRate
        self.decentralizationConstant = decentralizationConstant
        self.extraEntropy = extraEntropy
        self.protocolVersion = protocolVersion

        self.minPoolCost = minPoolCost
        self.adaPerUtxoByte = adaPerUtxoByte
        self.costModels = costModels
        self.executionCosts = executionCosts
        self.maxTxExUnits = maxTxExUnits
        self.maxBlockExUnits = maxBlockExUnits
        self.maxValueSize = maxValueSize
        self.collateralPercentage = collateralPercentage

        self.maxCollateralInputs = maxCollateralInputs
        self.poolVotingThresholds = poolVotingThresholds
        self.drepVotingThresholds = drepVotingThresholds
        self.minCommitteeSize = minCommitteeSize
        self.committeeTermLimit = committeeTermLimit

        self.governanceActionValidityPeriod = governanceActionValidityPeriod
        self.governanceActionDeposit = governanceActionDeposit
        self.drepDeposit = drepDeposit
        self.drepInactivityPeriod = drepInactivityPeriod
        self.minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        minFeeA = try container.decodeIfPresent(Coin.self, forKey: .minFeeA)
        minFeeB = try container.decodeIfPresent(Coin.self, forKey: .minFeeB)
        maxBlockBodySize = try container.decodeIfPresent(UInt32.self, forKey: .maxBlockBodySize)
        maxTransactionSize = try container.decodeIfPresent(UInt32.self, forKey: .maxTransactionSize)
        maxBlockHeaderSize = try container.decodeIfPresent(UInt16.self, forKey: .maxBlockHeaderSize)

        keyDeposit = try container.decodeIfPresent(Coin.self, forKey: .keyDeposit)
        poolDeposit = try container.decodeIfPresent(Coin.self, forKey: .poolDeposit)
        maximumEpoch = try container.decodeIfPresent(EpochInterval.self, forKey: .maximumEpoch)
        nOpt = try container.decodeIfPresent(UInt16.self, forKey: .nOpt)
        poolPledgeInfluence = try container.decodeIfPresent(
            NonNegativeInterval.self, forKey: .poolPledgeInfluence)

        expansionRate = try container.decodeIfPresent(UnitInterval.self, forKey: .expansionRate)
        treasuryGrowthRate = try container.decodeIfPresent(
            UnitInterval.self, forKey: .treasuryGrowthRate)
        decentralizationConstant = try container.decodeIfPresent(
            UnitInterval.self, forKey: .decentralizationConstant)
        extraEntropy = try container.decodeIfPresent(UInt32.self, forKey: .extraEntropy)
        protocolVersion = try container.decodeIfPresent(
            ProtocolVersion.self, forKey: .protocolVersion)

        minPoolCost = try container.decodeIfPresent(Coin.self, forKey: .minPoolCost)
        adaPerUtxoByte = try container.decodeIfPresent(Coin.self, forKey: .adaPerUtxoByte)
        costModels = try container.decodeIfPresent(CostModels.self, forKey: .costModels)
        executionCosts = try container.decodeIfPresent(ExUnitPrices.self, forKey: .executionCosts)
        maxTxExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxTxExUnits)
        maxBlockExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxBlockExUnits)
        maxValueSize = try container.decodeIfPresent(UInt32.self, forKey: .maxValueSize)
        collateralPercentage = try container.decodeIfPresent(
            UInt16.self, forKey: .collateralPercentage)

        maxCollateralInputs = try container.decodeIfPresent(
            UInt16.self, forKey: .maxCollateralInputs)
        poolVotingThresholds = try container.decodeIfPresent(
            PoolVotingThresholds.self, forKey: .poolVotingThresholds)
        drepVotingThresholds = try container.decodeIfPresent(
            DrepVotingThresholds.self, forKey: .drepVotingThresholds)
        minCommitteeSize = try container.decodeIfPresent(UInt16.self, forKey: .minCommitteeSize)
        committeeTermLimit = try container.decodeIfPresent(
            EpochInterval.self, forKey: .committeeTermLimit)

        governanceActionValidityPeriod = try container.decodeIfPresent(
            EpochInterval.self, forKey: .governanceActionValidityPeriod)
        governanceActionDeposit = try container.decodeIfPresent(
            Coin.self, forKey: .governanceActionDeposit)
        drepDeposit = try container.decodeIfPresent(Coin.self, forKey: .drepDeposit)
        drepInactivityPeriod = try container.decodeIfPresent(
            EpochInterval.self, forKey: .drepInactivityPeriod)
        minFeeRefScriptCoinsPerByte = try container.decodeIfPresent(
            NonNegativeInterval.self, forKey: .minFeeRefScriptCoinsPerByte)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(minFeeA, forKey: .minFeeA)
        try container.encodeIfPresent(minFeeB, forKey: .minFeeB)
        try container.encodeIfPresent(maxBlockBodySize, forKey: .maxBlockBodySize)
        try container.encodeIfPresent(maxTransactionSize, forKey: .maxTransactionSize)
        try container.encodeIfPresent(maxBlockHeaderSize, forKey: .maxBlockHeaderSize)

        try container.encodeIfPresent(keyDeposit, forKey: .keyDeposit)
        try container.encodeIfPresent(poolDeposit, forKey: .poolDeposit)
        try container.encodeIfPresent(maximumEpoch, forKey: .maximumEpoch)
        try container.encodeIfPresent(nOpt, forKey: .nOpt)
        try container.encodeIfPresent(poolPledgeInfluence, forKey: .poolPledgeInfluence)

        try container.encodeIfPresent(expansionRate, forKey: .expansionRate)
        try container.encodeIfPresent(treasuryGrowthRate, forKey: .treasuryGrowthRate)
        try container.encodeIfPresent(decentralizationConstant, forKey: .decentralizationConstant)
        try container.encodeIfPresent(extraEntropy, forKey: .extraEntropy)
        try container.encodeIfPresent(protocolVersion, forKey: .protocolVersion)

        try container.encodeIfPresent(minPoolCost, forKey: .minPoolCost)
        try container.encodeIfPresent(adaPerUtxoByte, forKey: .adaPerUtxoByte)
        try container.encodeIfPresent(costModels, forKey: .costModels)
        try container.encodeIfPresent(executionCosts, forKey: .executionCosts)
        try container.encodeIfPresent(maxTxExUnits, forKey: .maxTxExUnits)
        try container.encodeIfPresent(maxBlockExUnits, forKey: .maxBlockExUnits)
        try container.encodeIfPresent(maxValueSize, forKey: .maxValueSize)
        try container.encodeIfPresent(collateralPercentage, forKey: .collateralPercentage)

        try container.encodeIfPresent(maxCollateralInputs, forKey: .maxCollateralInputs)
        try container.encodeIfPresent(poolVotingThresholds, forKey: .poolVotingThresholds)
        try container.encodeIfPresent(drepVotingThresholds, forKey: .drepVotingThresholds)
        try container.encodeIfPresent(minCommitteeSize, forKey: .minCommitteeSize)
        try container.encodeIfPresent(committeeTermLimit, forKey: .committeeTermLimit)

        try container.encodeIfPresent(
            governanceActionValidityPeriod, forKey: .governanceActionValidityPeriod)
        try container.encodeIfPresent(governanceActionDeposit, forKey: .governanceActionDeposit)
        try container.encodeIfPresent(drepDeposit, forKey: .drepDeposit)
        try container.encodeIfPresent(drepInactivityPeriod, forKey: .drepInactivityPeriod)
        try container.encodeIfPresent(
            minFeeRefScriptCoinsPerByte, forKey: .minFeeRefScriptCoinsPerByte)
    }

    public init(from primitive: Primitive) throws {
        var pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d):
            pairs = Array(d)
        case .orderedDict(let od):
            pairs = od.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
        }

        var dict = [Int: Primitive]()
        for (key, value) in pairs {
            switch key {
            case .int(let keyValue) where Int(exactly: keyValue) != nil:
                dict[Int(keyValue)] = value
            case .uint(let keyValue) where Int(exactly: keyValue) != nil:
                dict[Int(keyValue)] = value
            default:
                throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
            }
        }

        /// The unsigned integer under `key`, or `nil` when there is none. A
        /// value outside the field's range fails to decode, as in the ledger.
        func number<T: FixedWidthInteger & UnsignedInteger>(_ key: CodingKeys) throws -> T? {
            guard let primitive = dict[key.rawValue] else { return nil }
            let value: T?
            switch primitive {
            case .uint(let v): value = T(exactly: v)
            case .int(let v): value = T(exactly: v)
            default: value = nil
            }
            guard let value else {
                throw CardanoCoreError.deserializeError(
                    "Protocol parameter \(key) out of range for \(T.self): \(primitive)")
            }
            return value
        }

        minFeeA = try number(.minFeeA)
        minFeeB = try number(.minFeeB)

        maxBlockBodySize = try number(.maxBlockBodySize)

        maxTransactionSize = try number(.maxTransactionSize)

        maxBlockHeaderSize = try number(.maxBlockHeaderSize)

        keyDeposit = try number(.keyDeposit)
        poolDeposit = try number(.poolDeposit)

        maximumEpoch = try number(.maximumEpoch)

        nOpt = try number(.nOpt)

        if let poolPledgeInfluencePrimitive = dict[CodingKeys.poolPledgeInfluence.rawValue] {
            poolPledgeInfluence = try NonNegativeInterval(from: poolPledgeInfluencePrimitive)
        } else {
            poolPledgeInfluence = nil
        }

        if let expansionRatePrimitive = dict[CodingKeys.expansionRate.rawValue] {
            expansionRate = try UnitInterval(from: expansionRatePrimitive)
        } else {
            expansionRate = nil
        }

        if let treasuryGrowthRatePrimitive = dict[CodingKeys.treasuryGrowthRate.rawValue] {
            treasuryGrowthRate = try UnitInterval(from: treasuryGrowthRatePrimitive)
        } else {
            treasuryGrowthRate = nil
        }

        if let decentralizationConstantPrimitive = dict[
            CodingKeys.decentralizationConstant.rawValue]
        {
            decentralizationConstant = try UnitInterval(from: decentralizationConstantPrimitive)
        } else {
            decentralizationConstant = nil
        }

        extraEntropy = try number(.extraEntropy)

        if let protocolVersionPrimitive = dict[CodingKeys.protocolVersion.rawValue] {
            protocolVersion = try ProtocolVersion(from: protocolVersionPrimitive)
        } else {
            protocolVersion = nil
        }

        minPoolCost = try number(.minPoolCost)
        adaPerUtxoByte = try number(.adaPerUtxoByte)

        if let costModelsPrimitive = dict[CodingKeys.costModels.rawValue] {
            costModels = try CostModels(from: costModelsPrimitive)
        } else {
            costModels = nil
        }

        if let executionCostsPrimitive = dict[CodingKeys.executionCosts.rawValue] {
            executionCosts = try ExUnitPrices(from: executionCostsPrimitive)
        } else {
            executionCosts = nil
        }

        if let maxTxExUnitsPrimitive = dict[CodingKeys.maxTxExUnits.rawValue] {
            maxTxExUnits = try ExUnits(from: maxTxExUnitsPrimitive)
        } else {
            maxTxExUnits = nil
        }

        if let maxBlockExUnitsPrimitive = dict[CodingKeys.maxBlockExUnits.rawValue] {
            maxBlockExUnits = try ExUnits(from: maxBlockExUnitsPrimitive)
        } else {
            maxBlockExUnits = nil
        }

        maxValueSize = try number(.maxValueSize)
        collateralPercentage = try number(.collateralPercentage)
        maxCollateralInputs = try number(.maxCollateralInputs)

        if let poolVotingThresholdsPrimitive = dict[CodingKeys.poolVotingThresholds.rawValue] {
            poolVotingThresholds = try PoolVotingThresholds(from: poolVotingThresholdsPrimitive)
        } else {
            poolVotingThresholds = nil
        }

        if let drepVotingThresholdsPrimitive = dict[CodingKeys.drepVotingThresholds.rawValue] {
            drepVotingThresholds = try DrepVotingThresholds(from: drepVotingThresholdsPrimitive)
        } else {
            drepVotingThresholds = nil
        }

        minCommitteeSize = try number(.minCommitteeSize)
        committeeTermLimit = try number(.committeeTermLimit)
        governanceActionValidityPeriod = try number(.governanceActionValidityPeriod)

        governanceActionDeposit = try number(.governanceActionDeposit)
        drepDeposit = try number(.drepDeposit)

        drepInactivityPeriod = try number(.drepInactivityPeriod)

        if let minFeeRefScriptCoinsPerBytePrimitive = dict[
            CodingKeys.minFeeRefScriptCoinsPerByte.rawValue]
        {
            minFeeRefScriptCoinsPerByte = try NonNegativeInterval(
                from: minFeeRefScriptCoinsPerBytePrimitive)
        } else {
            minFeeRefScriptCoinsPerByte = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        if let minFeeA = minFeeA {
            dict[.uint(UInt64(CodingKeys.minFeeA.rawValue))] = .uint(UInt64(minFeeA))
        }
        if let minFeeB = minFeeB {
            dict[.uint(UInt64(CodingKeys.minFeeB.rawValue))] = .uint(UInt64(minFeeB))
        }
        if let maxBlockBodySize = maxBlockBodySize {
            dict[.uint(UInt64(CodingKeys.maxBlockBodySize.rawValue))] = .uint(UInt64(maxBlockBodySize))
        }
        if let maxTransactionSize = maxTransactionSize {
            dict[.uint(UInt64(CodingKeys.maxTransactionSize.rawValue))] = .uint(UInt64(maxTransactionSize))
        }
        if let maxBlockHeaderSize = maxBlockHeaderSize {
            dict[.uint(UInt64(CodingKeys.maxBlockHeaderSize.rawValue))] = .uint(UInt64(maxBlockHeaderSize))
        }

        if let keyDeposit = keyDeposit {
            dict[.uint(UInt64(CodingKeys.keyDeposit.rawValue))] = .uint(UInt64(keyDeposit))
        }
        if let poolDeposit = poolDeposit {
            dict[.uint(UInt64(CodingKeys.poolDeposit.rawValue))] = .uint(UInt64(poolDeposit))
        }
        if let maximumEpoch = maximumEpoch {
            dict[.uint(UInt64(CodingKeys.maximumEpoch.rawValue))] = .uint(UInt64(maximumEpoch))
        }
        if let nOpt = nOpt {
            dict[.uint(UInt64(CodingKeys.nOpt.rawValue))] = .uint(UInt64(nOpt))
        }
        if let poolPledgeInfluence = poolPledgeInfluence {
            dict[.uint(UInt64(CodingKeys.poolPledgeInfluence.rawValue))] =
                try poolPledgeInfluence.toPrimitive()
        }

        if let expansionRate = expansionRate {
            dict[.uint(UInt64(CodingKeys.expansionRate.rawValue))] = try expansionRate.toPrimitive()
        }
        if let treasuryGrowthRate = treasuryGrowthRate {
            dict[.uint(UInt64(CodingKeys.treasuryGrowthRate.rawValue))] =
                try treasuryGrowthRate.toPrimitive()
        }
        if let decentralizationConstant = decentralizationConstant {
            dict[.uint(UInt64(CodingKeys.decentralizationConstant.rawValue))] =
                try decentralizationConstant.toPrimitive()
        }
        if let extraEntropy = extraEntropy {
            dict[.uint(UInt64(CodingKeys.extraEntropy.rawValue))] = .uint(UInt64(extraEntropy))
        }
        if let protocolVersion = protocolVersion {
            dict[.uint(UInt64(CodingKeys.protocolVersion.rawValue))] = try protocolVersion.toPrimitive()
        }

        if let minPoolCost = minPoolCost {
            dict[.uint(UInt64(CodingKeys.minPoolCost.rawValue))] = .uint(UInt64(minPoolCost))
        }
        if let adaPerUtxoByte = adaPerUtxoByte {
            dict[.uint(UInt64(CodingKeys.adaPerUtxoByte.rawValue))] = .uint(UInt64(adaPerUtxoByte))
        }
        if let costModels = costModels {
            dict[.uint(UInt64(CodingKeys.costModels.rawValue))] = try costModels.toPrimitive()
        }
        if let executionCosts = executionCosts {
            dict[.uint(UInt64(CodingKeys.executionCosts.rawValue))] = try executionCosts.toPrimitive()
        }
        if let maxTxExUnits = maxTxExUnits {
            dict[.uint(UInt64(CodingKeys.maxTxExUnits.rawValue))] = try maxTxExUnits.toPrimitive()
        }
        if let maxBlockExUnits = maxBlockExUnits {
            dict[.uint(UInt64(CodingKeys.maxBlockExUnits.rawValue))] = try maxBlockExUnits.toPrimitive()
        }
        if let maxValueSize = maxValueSize {
            dict[.uint(UInt64(CodingKeys.maxValueSize.rawValue))] = .uint(UInt64(maxValueSize))
        }
        if let collateralPercentage = collateralPercentage {
            dict[.uint(UInt64(CodingKeys.collateralPercentage.rawValue))] = .uint(UInt64(collateralPercentage))
        }

        if let maxCollateralInputs = maxCollateralInputs {
            dict[.uint(UInt64(CodingKeys.maxCollateralInputs.rawValue))] = .uint(UInt64(maxCollateralInputs))
        }
        if let poolVotingThresholds = poolVotingThresholds {
            dict[.uint(UInt64(CodingKeys.poolVotingThresholds.rawValue))] =
                try poolVotingThresholds.toPrimitive()
        }
        if let drepVotingThresholds = drepVotingThresholds {
            dict[.uint(UInt64(CodingKeys.drepVotingThresholds.rawValue))] =
                try drepVotingThresholds.toPrimitive()
        }
        if let minCommitteeSize = minCommitteeSize {
            dict[.uint(UInt64(CodingKeys.minCommitteeSize.rawValue))] = .uint(UInt64(minCommitteeSize))
        }
        if let committeeTermLimit = committeeTermLimit {
            dict[.uint(UInt64(CodingKeys.committeeTermLimit.rawValue))] = .uint(UInt64(committeeTermLimit))
        }

        if let governanceActionValidityPeriod = governanceActionValidityPeriod {
            dict[.uint(UInt64(CodingKeys.governanceActionValidityPeriod.rawValue))] = .integer(governanceActionValidityPeriod)
        }
        if let governanceActionDeposit = governanceActionDeposit {
            dict[.uint(UInt64(CodingKeys.governanceActionDeposit.rawValue))] = .integer(governanceActionDeposit)
        }
        if let drepDeposit = drepDeposit {
            dict[.uint(UInt64(CodingKeys.drepDeposit.rawValue))] = .uint(UInt64(drepDeposit))
        }
        if let drepInactivityPeriod = drepInactivityPeriod {
            dict[.uint(UInt64(CodingKeys.drepInactivityPeriod.rawValue))] = .uint(UInt64(drepInactivityPeriod))
        }
        if let minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte {
            dict[.uint(UInt64(CodingKeys.minFeeRefScriptCoinsPerByte.rawValue))] =
                try minFeeRefScriptCoinsPerByte.toPrimitive()
        }

        // In ascending field order, so an update always encodes the same way.
        dict.sort { lhs, rhs in
            guard case .uint(let l) = lhs.key, case .uint(let r) = rhs.key else { return false }
            return l < r
        }
        return .orderedDict(dict)
    }
}

// MARK: - ProtocolParamUpdate + ProtocolParameters conversion

extension ProtocolParamUpdate {
    /// Builds a `ProtocolParamUpdate` from the current network `ProtocolParameters`.
    ///
    /// Useful as a starting point for a `ParameterChangeAction`: populate all
    /// fields from the current params and then nil-out the fields you do NOT
    /// want to change. Rates are copied exactly, reduced as the ledger holds
    /// them; fields that have no clean on-chain representation are set to
    /// `nil` and must be supplied manually if needed.
    public init(from p: ProtocolParameters) {
        func unit(_ value: UnitInterval) -> UnitInterval {
            let (n, d) = LedgerRational.reduced(value.numerator, value.denominator)
            return UnitInterval(numerator: n, denominator: d)
        }
        func nonNegative(_ value: NonNegativeInterval) -> NonNegativeInterval {
            let (n, d) = LedgerRational.reduced(value.numerator, value.denominator)
            return NonNegativeInterval(numerator: n, denominator: d)
        }
        minFeeA = p.txFeePerByte
        minFeeB = p.txFeeFixed
        maxBlockBodySize = p.maxBlockBodySize
        maxTransactionSize = p.maxTxSize
        maxBlockHeaderSize = p.maxBlockHeaderSize
        keyDeposit = p.stakeAddressDeposit
        poolDeposit = p.stakePoolDeposit
        maximumEpoch = p.poolRetireMaxEpoch
        nOpt = p.stakePoolTargetNum
        poolPledgeInfluence = nonNegative(p.poolPledgeInfluence)
        expansionRate = unit(p.monetaryExpansion)
        treasuryGrowthRate = unit(p.treasuryCut)
        decentralizationConstant = nil
        extraEntropy = nil
        protocolVersion = ProtocolVersion(
            major: Int(p.protocolVersion.major), minor: Int(p.protocolVersion.minor))
        minPoolCost = p.minPoolCost
        adaPerUtxoByte = p.utxoCostPerByte

        costModels = try? CostModels([
            0: p.costModels.PlutusV1,
            1: p.costModels.PlutusV2,
            2: p.costModels.PlutusV3,
        ])

        executionCosts = ExUnitPrices(
            memPrice: nonNegative(p.executionUnitPrices.priceMemory),
            stepPrice: nonNegative(p.executionUnitPrices.priceSteps))

        maxTxExUnits = ExUnits(
            mem: p.maxTxExecutionUnits.memory, steps: p.maxTxExecutionUnits.steps)
        maxBlockExUnits = ExUnits(
            mem: p.maxBlockExecutionUnits.memory, steps: p.maxBlockExecutionUnits.steps)
        maxValueSize = p.maxValueSize
        collateralPercentage = p.collateralPercentage
        maxCollateralInputs = p.maxCollateralInputs

        let pool = p.poolVotingThresholds.ledgerOrder.map(unit)
        poolVotingThresholds = PoolVotingThresholds(
            motionNoConfidence: pool[0],
            committeeNormal: pool[1],
            committeeNoConfidence: pool[2],
            hardForkInitiation: pool[3],
            ppSecurityGroup: pool[4])
        // ledgerOrder always holds the ten DRep thresholds.
        drepVotingThresholds = DrepVotingThresholds(ledgerOrder: p.dRepVotingThresholds.ledgerOrder.map(unit))

        minCommitteeSize = p.committeeMinSize
        committeeTermLimit = p.committeeMaxTermLength
        governanceActionValidityPeriod = p.govActionLifetime
        governanceActionDeposit = p.govActionDeposit
        drepDeposit = p.dRepDeposit
        drepInactivityPeriod = p.dRepActivity
        minFeeRefScriptCoinsPerByte = p.minFeeRefScriptCostPerByte.map(nonNegative)
    }
}
