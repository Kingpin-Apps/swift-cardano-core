import Foundation

public struct ParameterChangeAction: GovernanceAction {
    public static var code: GovActionCode { get { .parameterChangeAction } }
    
    public var id: GovActionID?
    public let protocolParamUpdate: ProtocolParamUpdate
    public let policyHash: PolicyHash?
    
    public init(id: GovActionID, protocolParamUpdate: ProtocolParamUpdate, policyHash: PolicyHash?) {
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
        
        id = try container.decode(GovActionID.self)
        protocolParamUpdate = try container.decode(ProtocolParamUpdate.self)
        policyHash = try container.decode(PolicyHash.self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
                elements.count == 4,
                case let .int(code) = elements[0],
              code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }

        if case .int(_) = elements[1] {
            id = try GovActionID(from: elements[1])
        } else {
            id = nil
        }

        if case .int(_) = elements[1] {
            id = try GovActionID(from: elements[1])
        } else {
            id = nil
        }
        
        protocolParamUpdate = try ProtocolParamUpdate(from: elements[2])

        if case let .bytes(data) = elements[3] {
            policyHash = try PolicyHash(from: .bytes(data))
        } else {
            policyHash = nil
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
            .int(Self.code.rawValue),
            try id?.toPrimitive() ?? .null,
            try protocolParamUpdate.toPrimitive(),
            policyHash?.toPrimitive() ?? .null
        ])
    }
}

public struct ProtocolParamUpdate: CBORSerializable, Hashable, Equatable {
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
        poolPledgeInfluence = try container.decodeIfPresent(NonNegativeInterval.self, forKey: .poolPledgeInfluence)
        
        expansionRate = try container.decodeIfPresent(UnitInterval.self, forKey: .expansionRate)
        treasuryGrowthRate = try container.decodeIfPresent(UnitInterval.self, forKey: .treasuryGrowthRate)
        decentralizationConstant = try container.decodeIfPresent(UnitInterval.self, forKey: .decentralizationConstant)
        extraEntropy = try container.decodeIfPresent(UInt32.self, forKey: .extraEntropy)
        protocolVersion = try container.decodeIfPresent(ProtocolVersion.self, forKey: .protocolVersion)
        
        minPoolCost = try container.decodeIfPresent(Coin.self, forKey: .minPoolCost)
        adaPerUtxoByte = try container.decodeIfPresent(Coin.self, forKey: .adaPerUtxoByte)
        costModels = try container.decodeIfPresent(CostModels.self, forKey: .costModels)
        executionCosts = try container.decodeIfPresent(ExUnitPrices.self, forKey: .executionCosts)
        maxTxExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxTxExUnits)
        maxBlockExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxBlockExUnits)
        maxValueSize = try container.decodeIfPresent(UInt32.self, forKey: .maxValueSize)
        collateralPercentage = try container.decodeIfPresent(UInt16.self, forKey: .collateralPercentage)
        
        maxCollateralInputs = try container.decodeIfPresent(UInt16.self, forKey: .maxCollateralInputs)
        poolVotingThresholds = try container.decodeIfPresent(PoolVotingThresholds.self, forKey: .poolVotingThresholds)
        drepVotingThresholds = try container.decodeIfPresent(DrepVotingThresholds.self, forKey: .drepVotingThresholds)
        minCommitteeSize = try container.decodeIfPresent(UInt16.self, forKey: .minCommitteeSize)
        committeeTermLimit = try container.decodeIfPresent(EpochInterval.self, forKey: .committeeTermLimit)
        
        governanceActionValidityPeriod = try container.decodeIfPresent(EpochInterval.self, forKey: .governanceActionValidityPeriod)
        governanceActionDeposit = try container.decodeIfPresent(Coin.self, forKey: .governanceActionDeposit)
        drepDeposit = try container.decodeIfPresent(Coin.self, forKey: .drepDeposit)
        drepInactivityPeriod = try container.decodeIfPresent(EpochInterval.self, forKey: .drepInactivityPeriod)
        minFeeRefScriptCoinsPerByte = try container.decodeIfPresent(NonNegativeInterval.self, forKey: .minFeeRefScriptCoinsPerByte)
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
        
        try container.encodeIfPresent(governanceActionValidityPeriod, forKey: .governanceActionValidityPeriod)
        try container.encodeIfPresent(governanceActionDeposit, forKey: .governanceActionDeposit)
        try container.encodeIfPresent(drepDeposit, forKey: .drepDeposit)
        try container.encodeIfPresent(drepInactivityPeriod, forKey: .drepInactivityPeriod)
        try container.encodeIfPresent(minFeeRefScriptCoinsPerByte, forKey: .minFeeRefScriptCoinsPerByte)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .dict(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
        }
        
        var dict = [Int: Primitive]()
        for (key, value) in elements {
            guard case let .int(keyValue) = key else {
                throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
            }
            dict[Int(keyValue)] = value
        }
        
        if case let .int(minFeeAValue) = dict[CodingKeys.minFeeA.rawValue] {
            minFeeA = Coin(Int(minFeeAValue))
        } else {
            minFeeA = nil
        }
        
        if case let .int(minFeeBValue) = dict[CodingKeys.minFeeB.rawValue] {
            minFeeB = Coin(Int(minFeeBValue))
        } else {
            minFeeB = nil
        }
        
        if let maxBlockBodySizePrimitive = dict[CodingKeys.maxBlockBodySize.rawValue] {
            guard case let .int(value) = maxBlockBodySizePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maxBlockBodySize type")
            }
            maxBlockBodySize = UInt32(value)
        } else {
            maxBlockBodySize = nil
        }
        
        if let maxTransactionSizePrimitive = dict[CodingKeys.maxTransactionSize.rawValue] {
            guard case let .int(value) = maxTransactionSizePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maxTransactionSize type")
            }
            maxTransactionSize = UInt32(value)
        } else {
            maxTransactionSize = nil
        }
        
        if let maxBlockHeaderSizePrimitive = dict[CodingKeys.maxBlockHeaderSize.rawValue] {
            guard case let .int(value) = maxBlockHeaderSizePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maxBlockHeaderSize type")
            }
            maxBlockHeaderSize = UInt16(value)
        } else {
            maxBlockHeaderSize = nil
        }
        
        if case let .int(keyDepositValue) = dict[CodingKeys.keyDeposit.rawValue] {
            keyDeposit = Coin(Int(keyDepositValue))
        } else {
            keyDeposit = nil
        }
        
        if case let .int(poolDepositValue) = dict[CodingKeys.poolDeposit.rawValue] {
            poolDeposit = Coin(Int(poolDepositValue))
        } else {
            poolDeposit = nil
        }
        
        if let maximumEpochPrimitive = dict[CodingKeys.maximumEpoch.rawValue] {
            guard case let .int(value) = maximumEpochPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maximumEpoch type")
            }
            maximumEpoch = EpochInterval(value)
        } else {
            maximumEpoch = nil
        }
        
        if let nOptPrimitive = dict[CodingKeys.nOpt.rawValue] {
            guard case let .int(value) = nOptPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid nOpt type")
            }
            nOpt = UInt16(value)
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
        
        if let decentralizationConstantPrimitive = dict[CodingKeys.decentralizationConstant.rawValue] {
            decentralizationConstant = try UnitInterval(from: decentralizationConstantPrimitive)
        } else {
            decentralizationConstant = nil
        }
        
        if let extraEntropyPrimitive = dict[CodingKeys.extraEntropy.rawValue] {
            guard case let .int(value) = extraEntropyPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid extraEntropy type")
            }
            extraEntropy = UInt32(value)
        } else {
            extraEntropy = nil
        }
        
        if let protocolVersionPrimitive = dict[CodingKeys.protocolVersion.rawValue] {
            protocolVersion = try ProtocolVersion(from: protocolVersionPrimitive)
        } else {
            protocolVersion = nil
        }
        
        if case let .int(minPoolCostValue) = dict[CodingKeys.minPoolCost.rawValue] {
            minPoolCost = Coin(Int(minPoolCostValue))
        } else {
            minPoolCost = nil
        }
        
        if case let .int(adaPerUtxoByteValue) = dict[CodingKeys.adaPerUtxoByte.rawValue] {
            adaPerUtxoByte = Coin(Int(adaPerUtxoByteValue))
        } else {
            adaPerUtxoByte = nil
        }
        
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
        
        if let maxValueSizePrimitive = dict[CodingKeys.maxValueSize.rawValue] {
            guard case let .int(value) = maxValueSizePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maxValueSize type")
            }
            maxValueSize = UInt32(value)
        } else {
            maxValueSize = nil
        }
        
        if let collateralPercentagePrimitive = dict[CodingKeys.collateralPercentage.rawValue] {
            guard case let .int(value) = collateralPercentagePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid collateralPercentage type")
            }
            collateralPercentage = UInt16(value)
        } else {
            collateralPercentage = nil
        }
        
        if let maxCollateralInputsPrimitive = dict[CodingKeys.maxCollateralInputs.rawValue] {
            guard case let .int(value) = maxCollateralInputsPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid maxCollateralInputs type")
            }
            maxCollateralInputs = UInt16(value)
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
        
        if let minCommitteeSizePrimitive = dict[CodingKeys.minCommitteeSize.rawValue] {
            guard case let .int(value) = minCommitteeSizePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid minCommitteeSize type")
            }
            minCommitteeSize = UInt16(value)
        } else {
            minCommitteeSize = nil
        }
        
        if let committeeTermLimitPrimitive = dict[CodingKeys.committeeTermLimit.rawValue] {
            guard case let .int(value) = committeeTermLimitPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid committeeTermLimit type")
            }
            committeeTermLimit = EpochInterval(value)
        } else {
            committeeTermLimit = nil
        }
        
        if let governanceActionValidityPeriodPrimitive = dict[CodingKeys.governanceActionValidityPeriod.rawValue] {
            guard case let .int(value) = governanceActionValidityPeriodPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid governanceActionValidityPeriod type")
            }
            governanceActionValidityPeriod = EpochInterval(value)
        } else {
            governanceActionValidityPeriod = nil
        }
        
        if case let .int(governanceActionDepositValue) = dict[CodingKeys.governanceActionDeposit.rawValue] {
            governanceActionDeposit = Coin(Int(governanceActionDepositValue))
        } else {
            governanceActionDeposit = nil
        }
        
        if case let .int(drepDepositValue) = dict[CodingKeys.drepDeposit.rawValue] {
            drepDeposit = Coin(Int(drepDepositValue))
        } else {
            drepDeposit = nil
        }
        
        if let drepInactivityPeriodPrimitive = dict[CodingKeys.drepInactivityPeriod.rawValue] {
            guard case let .int(value) = drepInactivityPeriodPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid drepInactivityPeriod type")
            }
            drepInactivityPeriod = EpochInterval(value)
        } else {
            drepInactivityPeriod = nil
        }
        
        if let minFeeRefScriptCoinsPerBytePrimitive = dict[CodingKeys.minFeeRefScriptCoinsPerByte.rawValue] {
            minFeeRefScriptCoinsPerByte = try NonNegativeInterval(from: minFeeRefScriptCoinsPerBytePrimitive)
        } else {
            minFeeRefScriptCoinsPerByte = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]
        
        if let minFeeA = minFeeA {
            dict[.int(CodingKeys.minFeeA.rawValue)] = .int(Int(minFeeA))
        }
        if let minFeeB = minFeeB {
            dict[.int(CodingKeys.minFeeB.rawValue)] = .int(Int(minFeeB))
        }
        if let maxBlockBodySize = maxBlockBodySize {
            dict[.int(CodingKeys.maxBlockBodySize.rawValue)] = .int(Int(maxBlockBodySize))
        }
        if let maxTransactionSize = maxTransactionSize {
            dict[.int(CodingKeys.maxTransactionSize.rawValue)] = .int(Int(maxTransactionSize))
        }
        if let maxBlockHeaderSize = maxBlockHeaderSize {
            dict[.int(CodingKeys.maxBlockHeaderSize.rawValue)] = .int(Int(maxBlockHeaderSize))
        }
        
        if let keyDeposit = keyDeposit {
            dict[.int(CodingKeys.keyDeposit.rawValue)] = .int(Int(keyDeposit))
        }
        if let poolDeposit = poolDeposit {
            dict[.int(CodingKeys.poolDeposit.rawValue)] = .int(Int(poolDeposit))
        }
        if let maximumEpoch = maximumEpoch {
            dict[.int(CodingKeys.maximumEpoch.rawValue)] = .int(Int(maximumEpoch))
        }
        if let nOpt = nOpt {
            dict[.int(CodingKeys.nOpt.rawValue)] = .int(Int(nOpt))
        }
        if let poolPledgeInfluence = poolPledgeInfluence {
            dict[.int(CodingKeys.poolPledgeInfluence.rawValue)] = try poolPledgeInfluence.toPrimitive()
        }
        
        if let expansionRate = expansionRate {
            dict[.int(CodingKeys.expansionRate.rawValue)] = try expansionRate.toPrimitive()
        }
        if let treasuryGrowthRate = treasuryGrowthRate {
            dict[.int(CodingKeys.treasuryGrowthRate.rawValue)] = try treasuryGrowthRate.toPrimitive()
        }
        if let decentralizationConstant = decentralizationConstant {
            dict[.int(CodingKeys.decentralizationConstant.rawValue)] = try decentralizationConstant.toPrimitive()
        }
        if let extraEntropy = extraEntropy {
            dict[.int(CodingKeys.extraEntropy.rawValue)] = .int(Int(extraEntropy))
        }
        if let protocolVersion = protocolVersion {
            dict[.int(CodingKeys.protocolVersion.rawValue)] = try protocolVersion.toPrimitive()
        }
        
        if let minPoolCost = minPoolCost {
            dict[.int(CodingKeys.minPoolCost.rawValue)] = .int(Int(minPoolCost))
        }
        if let adaPerUtxoByte = adaPerUtxoByte {
            dict[.int(CodingKeys.adaPerUtxoByte.rawValue)] = .int(Int(adaPerUtxoByte))
        }
        if let costModels = costModels {
            dict[.int(CodingKeys.costModels.rawValue)] = try costModels.toPrimitive()
        }
        if let executionCosts = executionCosts {
            dict[.int(CodingKeys.executionCosts.rawValue)] = try executionCosts.toPrimitive()
        }
        if let maxTxExUnits = maxTxExUnits {
            dict[.int(CodingKeys.maxTxExUnits.rawValue)] = try maxTxExUnits.toPrimitive()
        }
        if let maxBlockExUnits = maxBlockExUnits {
            dict[.int(CodingKeys.maxBlockExUnits.rawValue)] = try maxBlockExUnits.toPrimitive()
        }
        if let maxValueSize = maxValueSize {
            dict[.int(CodingKeys.maxValueSize.rawValue)] = .int(Int(maxValueSize))
        }
        if let collateralPercentage = collateralPercentage {
            dict[.int(CodingKeys.collateralPercentage.rawValue)] = .int(Int(collateralPercentage))
        }
        
        if let maxCollateralInputs = maxCollateralInputs {
            dict[.int(CodingKeys.maxCollateralInputs.rawValue)] = .int(Int(maxCollateralInputs))
        }
        if let poolVotingThresholds = poolVotingThresholds {
            dict[.int(CodingKeys.poolVotingThresholds.rawValue)] = try poolVotingThresholds.toPrimitive()
        }
        if let drepVotingThresholds = drepVotingThresholds {
            dict[.int(CodingKeys.drepVotingThresholds.rawValue)] = try drepVotingThresholds.toPrimitive()
        }
        if let minCommitteeSize = minCommitteeSize {
            dict[.int(CodingKeys.minCommitteeSize.rawValue)] = .int(Int(minCommitteeSize))
        }
        if let committeeTermLimit = committeeTermLimit {
            dict[.int(CodingKeys.committeeTermLimit.rawValue)] = .int(Int(committeeTermLimit))
        }
        
        if let governanceActionValidityPeriod = governanceActionValidityPeriod {
            dict[.int(CodingKeys.governanceActionValidityPeriod.rawValue)] = .int(Int(governanceActionValidityPeriod))
        }
        if let governanceActionDeposit = governanceActionDeposit {
            dict[.int(CodingKeys.governanceActionDeposit.rawValue)] = .int(Int(governanceActionDeposit))
        }
        if let drepDeposit = drepDeposit {
            dict[.int(CodingKeys.drepDeposit.rawValue)] = .int(Int(drepDeposit))
        }
        if let drepInactivityPeriod = drepInactivityPeriod {
            dict[.int(CodingKeys.drepInactivityPeriod.rawValue)] = .int(Int(drepInactivityPeriod))
        }
        if let minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte {
            dict[.int(CodingKeys.minFeeRefScriptCoinsPerByte.rawValue)] = try minFeeRefScriptCoinsPerByte.toPrimitive()
        }
        
        return .dict(dict)
    }
}
