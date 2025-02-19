import Foundation

struct ParameterChangeAction: GovernanceAction {
    static var code: GovActionCode { get { .parameterChangeAction } }
    
    let id: GovActionID?
    let protocolParamUpdate: ProtocolParamUpdate
    let policyHash: PolicyHash?
    
    init(id: GovActionID, protocolParamUpdate: ProtocolParamUpdate, policyHash: PolicyHash?) {
        self.id = id
        self.protocolParamUpdate = protocolParamUpdate
        self.policyHash = policyHash
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        protocolParamUpdate = try container.decode(ProtocolParamUpdate.self)
        policyHash = try container.decode(PolicyHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(protocolParamUpdate)
        try container.encode(policyHash)
    }
}

struct ProtocolParamUpdate: Codable, Hashable, Equatable {
    var minFeeA: Coin?
    var minFeeB: Coin?
    var maxBlockBodySize: UInt32?
    var maxTransactionSize: UInt32?
    var maxBlockHeaderSize: UInt16?
    
    var keyDeposit: Coin?
    var poolDeposit: Coin?
    var maximumEpoch: EpochInterval?
    var nOpt: UInt16?
    var poolPledgeInfluence: NonNegativeInterval?
    
    var expansionRate: UnitInterval?
    var treasuryGrowthRate: UnitInterval?
    var decentralizationConstant: UnitInterval?
    var extraEntropy: UInt32?
    var protocolVersion: ProtocolVersion?
    
    var minPoolCost: Coin?
    var adaPerUtxoByte: Coin?
    var costModels: CostModels?
    var executionCosts: ExUnitPrices?
    var maxTxExUnits: ExUnits?
    var maxBlockExUnits: ExUnits?
    var maxValueSize: UInt32?
    var collateralPercentage: UInt16?
    
    var maxCollateralInputs: UInt16?
    var poolVotingThresholds: PoolVotingThresholds?
    var drepVotingThresholds: DrepVotingThresholds?
    var minCommitteeSize: UInt16?
    var committeeTermLimit: EpochInterval?
    
    var governanceActionValidityPeriod: EpochInterval?
    var governanceActionDeposit: Coin?
    var drepDeposit: Coin?
    var drepInactivityPeriod: EpochInterval?
    var minFeeRefScriptCoinsPerByte: NonNegativeInterval?
    
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
    
    init(
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
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
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
}
