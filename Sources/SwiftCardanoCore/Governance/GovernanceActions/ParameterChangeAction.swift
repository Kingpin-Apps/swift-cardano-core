import Foundation

struct ParameterChangeAction: Codable {
    public var code: Int { get { return 0 } }
    
    let id: GovActionID?
    let protocolParamUpdate: ProtocolParamUpdate
    let policyHash: PolicyHash?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 0 else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        protocolParamUpdate = try container.decode(ProtocolParamUpdate.self)
        policyHash = try container.decode(PolicyHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(id)
        try container.encode(protocolParamUpdate)
        try container.encode(policyHash)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var id: Data
//        var protocolParamUpdate: Data
//        var policyHash: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            id = list[1] as! Data
//            protocolParamUpdate = list[2] as! Data
//            policyHash = list[3] as! Data
//        } else if let tuple = value as? (Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            id = tuple.1 as! Data
//            protocolParamUpdate = tuple.2 as! Data
//            policyHash = tuple.3 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction data: \(value)")
//        }
//        
//        guard code == 14 else {
//            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type: \(code)")
//        }
//        
//        return ParameterChangeAction(
//            id: try GovActionID.fromPrimitive(id),
//            protocolParamUpdate: try ProtocolParamUpdate.fromPrimitive(protocolParamUpdate),
//            policyHash: try PolicyHash.fromPrimitive(policyHash)
//        ) as! T
//    }
}

struct ProtocolParamUpdate: Codable {
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
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var protocolParamUpdate = ProtocolParamUpdate()
//        
//        if let value = value as? [Int: Any] {
//            if let minFeeA = Coin(exactly: value[0] as! UInt64) {
//                protocolParamUpdate.minFeeA = minFeeA
//            }
//            
//            if let minFeeB = Coin(exactly: value[1] as! UInt64) {
//                protocolParamUpdate.minFeeB = minFeeB
//            }
//            
//            if let maxBlockBodySize = value[2] as? UInt32 {
//                protocolParamUpdate.maxBlockBodySize = maxBlockBodySize
//            }
//            
//            if let maxTransactionSize = value[3] as? UInt32 {
//                protocolParamUpdate.maxTransactionSize = maxTransactionSize
//            }
//            
//            if let maxBlockHeaderSize = value[4] as? UInt16 {
//                protocolParamUpdate.maxBlockHeaderSize = maxBlockHeaderSize
//            }
//            
//            if let keyDeposit = Coin(exactly: value[5] as! UInt64) {
//                protocolParamUpdate.keyDeposit = keyDeposit
//            }
//            
//            if let poolDeposit = Coin(exactly: value[6] as! UInt64) {
//                protocolParamUpdate.poolDeposit = poolDeposit
//            }
//            
//            if let maximumEpoch = EpochInterval(exactly: value[7] as! UInt32) {
//                protocolParamUpdate.maximumEpoch = maximumEpoch
//            }
//            
//            if let nOpt = value[8] as? UInt16 {
//                protocolParamUpdate.nOpt = nOpt
//            }
//            
//            if let poolPledgeInfluence = value[9] as? [Int] {
//                protocolParamUpdate.poolPledgeInfluence = try NonNegativeInterval
//                    .fromPrimitive(poolPledgeInfluence)
//            }
//            
//            if let expansionRate = value[10] as? [Int] {
//                protocolParamUpdate.expansionRate = try UnitInterval.fromPrimitive(expansionRate)
//            }
//            
//            if let treasuryGrowthRate = value[11] as? [Int] {
//                protocolParamUpdate.treasuryGrowthRate = try UnitInterval.fromPrimitive(treasuryGrowthRate)
//            }
//            
//            if let minPoolCost = Coin(exactly: value[12] as! UInt64) {
//                protocolParamUpdate.minPoolCost = minPoolCost
//            }
//            
//            if let adaPerUtxoByte = Coin(exactly: value[13] as! UInt64) {
//                protocolParamUpdate.adaPerUtxoByte = adaPerUtxoByte
//            }
//            
//            if let costModels = value[14] as? [Int: Any] {
//                protocolParamUpdate.costModels = try CostModels.fromPrimitive(costModels)
//            }
//            
//            if let executionCosts = value[15] as? [Int: Any] {
//                protocolParamUpdate.executionCosts = try ExUnitPrices.fromPrimitive(executionCosts)
//            }
//            
//            if let maxTxExUnits = value[16] as? [Int] {
//                protocolParamUpdate.maxTxExUnits = try ExUnits.fromPrimitive(maxTxExUnits)
//            }
//            
//            if let maxBlockExUnits = value[17] as? [Int] {
//                protocolParamUpdate.maxBlockExUnits = try ExUnits.fromPrimitive(maxBlockExUnits)
//            }
//            
//            if let maxValueSize = value[18] as? UInt32 {
//                protocolParamUpdate.maxValueSize = maxValueSize
//            }
//            
//            if let collateralPercentage = value[19] as? UInt16 {
//                protocolParamUpdate.collateralPercentage = collateralPercentage
//            }
//            
//            if let maxCollateralInputs = value[20] as? UInt16 {
//                protocolParamUpdate.maxCollateralInputs = maxCollateralInputs
//            }
//            
//            if let poolVotingThresholds = value[21] as? [Int] {
//                protocolParamUpdate.poolVotingThresholds = try PoolVotingThresholds.fromPrimitive(poolVotingThresholds)
//            }
//            
//            if let drepVotingThresholds = value[22] as? [Int] {
//                protocolParamUpdate.drepVotingThresholds = try DrepVotingThresholds.fromPrimitive(drepVotingThresholds)
//            }
//            
//            if let minCommitteeSize = value[23] as? UInt16 {
//                protocolParamUpdate.minCommitteeSize = minCommitteeSize
//            }
//            
//            if let committeeTermLimit = value[24] as? UInt32 {
//                protocolParamUpdate.committeeTermLimit = EpochInterval(exactly: committeeTermLimit)
//            }
//            
//            if let governanceActionValidityPeriod = value[25] as? UInt32 {
//                protocolParamUpdate.governanceActionValidityPeriod = EpochInterval(exactly: governanceActionValidityPeriod)
//            }
//            
//            if let governanceActionDeposit = Coin(exactly: value[26] as! UInt64) {
//                protocolParamUpdate.governanceActionDeposit = governanceActionDeposit
//            }
//            
//            if let drepDeposit = Coin(exactly: value[28] as! UInt64) {
//                protocolParamUpdate.drepDeposit = drepDeposit
//            }
//            
//            if let drepInactivityPeriod = value[29] as? UInt32 {
//                protocolParamUpdate.drepInactivityPeriod = EpochInterval(exactly: drepInactivityPeriod)
//            }
//            
//            if let minFeeRefScriptCoinsPerByte = value[30] as? [Int] {
//                protocolParamUpdate.minFeeRefScriptCoinsPerByte = try NonNegativeInterval.fromPrimitive(minFeeRefScriptCoinsPerByte)
//            }
//            
//            return protocolParamUpdate as! T
//        } else {
//            throw CardanoCoreError
//                .valueError(
//                    "Invalid value type for ProtocolParamUpdate: \(value)"
//                )
//        }
//        
//    }
}
