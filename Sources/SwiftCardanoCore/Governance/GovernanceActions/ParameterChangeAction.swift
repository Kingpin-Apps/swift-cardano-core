import Foundation

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
        case .int(let v): code = Int(v)
        case .uint(let v): code = Int(v)
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
            case .int(let keyValue):
                dict[Int(keyValue)] = value
            case .uint(let keyValue):
                dict[Int(keyValue)] = value
            default:
                throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
            }
        }

        func intValue(_ key: CodingKeys) -> Int? {
            switch dict[key.rawValue] {
            case .int(let v): return Int(v)
            case .uint(let v): return Int(v)
            default: return nil
            }
        }
        func uintValue(_ key: CodingKeys) -> UInt? {
            switch dict[key.rawValue] {
            case .int(let v): return UInt(v)
            case .uint(let v): return UInt(v)
            default: return nil
            }
        }

        minFeeA = intValue(.minFeeA).map { Coin($0) }
        minFeeB = intValue(.minFeeB).map { Coin($0) }

        if let v = intValue(.maxBlockBodySize) {
            maxBlockBodySize = UInt32(v)
        } else {
            maxBlockBodySize = nil
        }

        if let v = intValue(.maxTransactionSize) {
            maxTransactionSize = UInt32(v)
        } else {
            maxTransactionSize = nil
        }

        if let v = intValue(.maxBlockHeaderSize) {
            maxBlockHeaderSize = UInt16(v)
        } else {
            maxBlockHeaderSize = nil
        }

        keyDeposit = intValue(.keyDeposit).map { Coin($0) }
        poolDeposit = intValue(.poolDeposit).map { Coin($0) }

        if let v = intValue(.maximumEpoch) {
            maximumEpoch = EpochInterval(v)
        } else {
            maximumEpoch = nil
        }

        if let v = intValue(.nOpt) {
            nOpt = UInt16(v)
        } else {
            nOpt = nil
        }

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

        if let v = intValue(.extraEntropy) {
            extraEntropy = UInt32(v)
        } else {
            extraEntropy = nil
        }

        if let protocolVersionPrimitive = dict[CodingKeys.protocolVersion.rawValue] {
            protocolVersion = try ProtocolVersion(from: protocolVersionPrimitive)
        } else {
            protocolVersion = nil
        }

        minPoolCost = intValue(.minPoolCost).map { Coin($0) }
        adaPerUtxoByte = intValue(.adaPerUtxoByte).map { Coin($0) }

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

        if let v = intValue(.maxValueSize) { maxValueSize = UInt32(v) } else { maxValueSize = nil }
        if let v = intValue(.collateralPercentage) {
            collateralPercentage = UInt16(v)
        } else {
            collateralPercentage = nil
        }
        if let v = intValue(.maxCollateralInputs) {
            maxCollateralInputs = UInt16(v)
        } else {
            maxCollateralInputs = nil
        }

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

        if let v = intValue(.minCommitteeSize) {
            minCommitteeSize = UInt16(v)
        } else {
            minCommitteeSize = nil
        }
        if let v = intValue(.committeeTermLimit) {
            committeeTermLimit = EpochInterval(v)
        } else {
            committeeTermLimit = nil
        }
        if let v = intValue(.governanceActionValidityPeriod) {
            governanceActionValidityPeriod = EpochInterval(v)
        } else {
            governanceActionValidityPeriod = nil
        }

        governanceActionDeposit = intValue(.governanceActionDeposit).map { Coin($0) }
        drepDeposit = intValue(.drepDeposit).map { Coin($0) }

        if let v = intValue(.drepInactivityPeriod) {
            drepInactivityPeriod = EpochInterval(v)
        } else {
            drepInactivityPeriod = nil
        }

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
        var dict: [Primitive: Primitive] = [:]

        if let minFeeA = minFeeA {
            dict[.int(Int64(CodingKeys.minFeeA.rawValue))] = .int(Int64(minFeeA))
        }
        if let minFeeB = minFeeB {
            dict[.int(Int64(CodingKeys.minFeeB.rawValue))] = .int(Int64(minFeeB))
        }
        if let maxBlockBodySize = maxBlockBodySize {
            dict[.int(Int64(CodingKeys.maxBlockBodySize.rawValue))] = .int(Int64(maxBlockBodySize))
        }
        if let maxTransactionSize = maxTransactionSize {
            dict[.int(Int64(CodingKeys.maxTransactionSize.rawValue))] = .int(Int64(maxTransactionSize))
        }
        if let maxBlockHeaderSize = maxBlockHeaderSize {
            dict[.int(Int64(CodingKeys.maxBlockHeaderSize.rawValue))] = .int(Int64(maxBlockHeaderSize))
        }

        if let keyDeposit = keyDeposit {
            dict[.int(Int64(CodingKeys.keyDeposit.rawValue))] = .int(Int64(keyDeposit))
        }
        if let poolDeposit = poolDeposit {
            dict[.int(Int64(CodingKeys.poolDeposit.rawValue))] = .int(Int64(poolDeposit))
        }
        if let maximumEpoch = maximumEpoch {
            dict[.int(Int64(CodingKeys.maximumEpoch.rawValue))] = .int(Int64(maximumEpoch))
        }
        if let nOpt = nOpt {
            dict[.int(Int64(CodingKeys.nOpt.rawValue))] = .int(Int64(nOpt))
        }
        if let poolPledgeInfluence = poolPledgeInfluence {
            dict[.int(Int64(CodingKeys.poolPledgeInfluence.rawValue))] =
                try poolPledgeInfluence.toPrimitive()
        }

        if let expansionRate = expansionRate {
            dict[.int(Int64(CodingKeys.expansionRate.rawValue))] = try expansionRate.toPrimitive()
        }
        if let treasuryGrowthRate = treasuryGrowthRate {
            dict[.int(Int64(CodingKeys.treasuryGrowthRate.rawValue))] =
                try treasuryGrowthRate.toPrimitive()
        }
        if let decentralizationConstant = decentralizationConstant {
            dict[.int(Int64(CodingKeys.decentralizationConstant.rawValue))] =
                try decentralizationConstant.toPrimitive()
        }
        if let extraEntropy = extraEntropy {
            dict[.int(Int64(CodingKeys.extraEntropy.rawValue))] = .int(Int64(extraEntropy))
        }
        if let protocolVersion = protocolVersion {
            dict[.int(Int64(CodingKeys.protocolVersion.rawValue))] = try protocolVersion.toPrimitive()
        }

        if let minPoolCost = minPoolCost {
            dict[.int(Int64(CodingKeys.minPoolCost.rawValue))] = .int(Int64(minPoolCost))
        }
        if let adaPerUtxoByte = adaPerUtxoByte {
            dict[.int(Int64(CodingKeys.adaPerUtxoByte.rawValue))] = .int(Int64(adaPerUtxoByte))
        }
        if let costModels = costModels {
            dict[.int(Int64(CodingKeys.costModels.rawValue))] = try costModels.toPrimitive()
        }
        if let executionCosts = executionCosts {
            dict[.int(Int64(CodingKeys.executionCosts.rawValue))] = try executionCosts.toPrimitive()
        }
        if let maxTxExUnits = maxTxExUnits {
            dict[.int(Int64(CodingKeys.maxTxExUnits.rawValue))] = try maxTxExUnits.toPrimitive()
        }
        if let maxBlockExUnits = maxBlockExUnits {
            dict[.int(Int64(CodingKeys.maxBlockExUnits.rawValue))] = try maxBlockExUnits.toPrimitive()
        }
        if let maxValueSize = maxValueSize {
            dict[.int(Int64(CodingKeys.maxValueSize.rawValue))] = .int(Int64(maxValueSize))
        }
        if let collateralPercentage = collateralPercentage {
            dict[.int(Int64(CodingKeys.collateralPercentage.rawValue))] = .int(Int64(collateralPercentage))
        }

        if let maxCollateralInputs = maxCollateralInputs {
            dict[.int(Int64(CodingKeys.maxCollateralInputs.rawValue))] = .int(Int64(maxCollateralInputs))
        }
        if let poolVotingThresholds = poolVotingThresholds {
            dict[.int(Int64(CodingKeys.poolVotingThresholds.rawValue))] =
                try poolVotingThresholds.toPrimitive()
        }
        if let drepVotingThresholds = drepVotingThresholds {
            dict[.int(Int64(CodingKeys.drepVotingThresholds.rawValue))] =
                try drepVotingThresholds.toPrimitive()
        }
        if let minCommitteeSize = minCommitteeSize {
            dict[.int(Int64(CodingKeys.minCommitteeSize.rawValue))] = .int(Int64(minCommitteeSize))
        }
        if let committeeTermLimit = committeeTermLimit {
            dict[.int(Int64(CodingKeys.committeeTermLimit.rawValue))] = .int(Int64(committeeTermLimit))
        }

        if let governanceActionValidityPeriod = governanceActionValidityPeriod {
            dict[.int(Int64(CodingKeys.governanceActionValidityPeriod.rawValue))] = .int(
                Int64(governanceActionValidityPeriod))
        }
        if let governanceActionDeposit = governanceActionDeposit {
            dict[.int(Int64(CodingKeys.governanceActionDeposit.rawValue))] = .int(
                Int64(governanceActionDeposit))
        }
        if let drepDeposit = drepDeposit {
            dict[.int(Int64(CodingKeys.drepDeposit.rawValue))] = .int(Int64(drepDeposit))
        }
        if let drepInactivityPeriod = drepInactivityPeriod {
            dict[.int(Int64(CodingKeys.drepInactivityPeriod.rawValue))] = .int(Int64(drepInactivityPeriod))
        }
        if let minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte {
            dict[.int(Int64(CodingKeys.minFeeRefScriptCoinsPerByte.rawValue))] =
                try minFeeRefScriptCoinsPerByte.toPrimitive()
        }

        return .dict(dict)
    }
}

// MARK: - ProtocolParamUpdate + ProtocolParameters conversion

extension ProtocolParamUpdate {
    /// Builds a `ProtocolParamUpdate` from the current network `ProtocolParameters`.
    ///
    /// Useful as a starting point for a `ParameterChangeAction`: populate all
    /// fields from the current params and then nil-out the fields you do NOT
    /// want to change.  Double-valued rates are approximated as rationals with
    /// 10⁹ precision; fields that have no clean on-chain representation are set
    /// to `nil` and must be supplied manually if needed.
    public init(from p: ProtocolParameters) {
        minFeeA = Coin(p.txFeePerByte)
        minFeeB = Coin(p.txFeeFixed)
        maxBlockBodySize = UInt32(p.maxBlockBodySize)
        maxTransactionSize = UInt32(p.maxTxSize)
        maxBlockHeaderSize = UInt16(p.maxBlockHeaderSize)
        keyDeposit = Coin(p.stakeAddressDeposit)
        poolDeposit = Coin(p.stakePoolDeposit)
        maximumEpoch = EpochInterval(p.poolRetireMaxEpoch)
        nOpt = UInt16(p.stakePoolTargetNum)
        poolPledgeInfluence = doubleToNonNegativeInterval(p.poolPledgeInfluence)
        expansionRate = doubleToUnitInterval(p.monetaryExpansion)
        treasuryGrowthRate = doubleToUnitInterval(p.treasuryCut)
        decentralizationConstant = nil
        extraEntropy = nil
        protocolVersion = ProtocolVersion(
            major: p.protocolVersion.major, minor: p.protocolVersion.minor)
        minPoolCost = Coin(p.minPoolCost)
        adaPerUtxoByte = Coin(p.utxoCostPerByte)

        costModels = try? CostModels([
            0: p.costModels.PlutusV1,
            1: p.costModels.PlutusV2,
            2: p.costModels.PlutusV3,
        ])

        if let mem = doubleToNonNegativeInterval(p.executionUnitPrices.priceMemory),
            let step = doubleToNonNegativeInterval(p.executionUnitPrices.priceSteps)
        {
            executionCosts = ExUnitPrices(memPrice: mem, stepPrice: step)
        } else {
            executionCosts = nil
        }

        maxTxExUnits = ExUnits(
            mem: UInt64(p.maxTxExecutionUnits.memory), steps: UInt64(p.maxTxExecutionUnits.steps))
        maxBlockExUnits = ExUnits(
            mem: UInt64(p.maxBlockExecutionUnits.memory), steps: UInt64(p.maxBlockExecutionUnits.steps))
        maxValueSize = UInt32(p.maxValueSize)
        collateralPercentage = UInt16(p.collateralPercentage)
        maxCollateralInputs = UInt16(p.maxCollateralInputs)

        let pvt = p.poolVotingThresholds
        if let cnc = doubleToUnitInterval(pvt.committeeNoConfidence),
            let cn = doubleToUnitInterval(pvt.committeeNormal),
            let hfi = doubleToUnitInterval(pvt.hardForkInitiation),
            let mnc = doubleToUnitInterval(pvt.motionNoConfidence),
            let psg = doubleToUnitInterval(pvt.ppSecurityGroup)
        {
            poolVotingThresholds = PoolVotingThresholds(
                committeeNoConfidence: cnc,
                committeeNormal: cn,
                hardForkInitiation: hfi,
                motionNoConfidence: mnc,
                ppSecurityGroup: psg
            )
        } else {
            poolVotingThresholds = nil
        }

        // drep_voting_thresholds CDDL order:
        // [motionNoConfidence, committeeNormal, committeeNoConfidence, updateToConstitution,
        //  hardForkInitiation, ppNetworkGroup, ppEconomicGroup, ppTechnicalGroup, ppGovGroup, treasuryWithdrawal]
        let dvt = p.dRepVotingThresholds
        let dvtDoubles = [
            dvt.motionNoConfidence, dvt.committeeNormal, dvt.committeeNoConfidence,
            dvt.updateToConstitution, dvt.hardForkInitiation, dvt.ppNetworkGroup,
            dvt.ppEconomicGroup, dvt.ppTechnicalGroup, dvt.ppGovGroup, dvt.treasuryWithdrawal,
        ]
        let dvtIntervals = dvtDoubles.compactMap { doubleToUnitInterval($0) }
        drepVotingThresholds =
            dvtIntervals.count == 10
            ? DrepVotingThresholds(thresholds: dvtIntervals) : nil

        minCommitteeSize = UInt16(p.committeeMinSize)
        committeeTermLimit = EpochInterval(p.committeeMaxTermLength)
        governanceActionValidityPeriod = EpochInterval(p.govActionLifetime)
        governanceActionDeposit = Coin(p.govActionDeposit)
        drepDeposit = Coin(p.dRepDeposit)
        drepInactivityPeriod = EpochInterval(p.dRepActivity)
        // minFeeRefScriptCoinsPerByte is a NonNegativeInterval on-chain; the Int API
        // value cannot be cleanly represented without knowing the scaling factor.
        minFeeRefScriptCoinsPerByte = nil
    }
}
