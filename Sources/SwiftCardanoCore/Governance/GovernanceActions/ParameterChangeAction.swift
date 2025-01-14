import Foundation

struct ParameterChangeAction: ArrayCBORSerializable {
    public var code: Int { get { return 0 } }
    
    let id: GovActionID?
    let protocolParamUpdate: ProtocolParamUpdate
    let policyHash: PolicyHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var id: Data
        var protocolParamUpdate: Data
        var policyHash: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            id = list[1] as! Data
            protocolParamUpdate = list[2] as! Data
            policyHash = list[3] as! Data
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            id = tuple.1 as! Data
            protocolParamUpdate = tuple.2 as! Data
            policyHash = tuple.3 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction data: \(value)")
        }
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type: \(code)")
        }
        
        return ParameterChangeAction(
            id: try GovActionID.fromPrimitive(id),
            protocolParamUpdate: try ProtocolParamUpdate.fromPrimitive(protocolParamUpdate),
            policyHash: try PolicyHash.fromPrimitive(policyHash)
        ) as! T
    }
}

struct ProtocolParamUpdate: MapCBORSerializable {
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
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var protocolParamUpdate = ProtocolParamUpdate()
        
        if let value = value as? [Int: Any] {
            if let minFeeA = Coin(exactly: value[0] as! UInt64) {
                protocolParamUpdate.minFeeA = minFeeA
            }
            
            if let minFeeB = Coin(exactly: value[1] as! UInt64) {
                protocolParamUpdate.minFeeB = minFeeB
            }
            
            if let maxBlockBodySize = value[2] as? UInt32 {
                protocolParamUpdate.maxBlockBodySize = maxBlockBodySize
            }
            
            if let maxTransactionSize = value[3] as? UInt32 {
                protocolParamUpdate.maxTransactionSize = maxTransactionSize
            }
            
            if let maxBlockHeaderSize = value[4] as? UInt16 {
                protocolParamUpdate.maxBlockHeaderSize = maxBlockHeaderSize
            }
            
            if let keyDeposit = Coin(exactly: value[5] as! UInt64) {
                protocolParamUpdate.keyDeposit = keyDeposit
            }
            
            if let poolDeposit = Coin(exactly: value[6] as! UInt64) {
                protocolParamUpdate.poolDeposit = poolDeposit
            }
            
            if let maximumEpoch = EpochInterval(exactly: value[7] as! UInt32) {
                protocolParamUpdate.maximumEpoch = maximumEpoch
            }
            
            if let nOpt = value[8] as? UInt16 {
                protocolParamUpdate.nOpt = nOpt
            }
            
            if let poolPledgeInfluence = value[9] as? [Int] {
                protocolParamUpdate.poolPledgeInfluence = try NonNegativeInterval
                    .fromPrimitive(poolPledgeInfluence)
            }
            
            if let expansionRate = value[10] as? [Int] {
                protocolParamUpdate.expansionRate = try UnitInterval.fromPrimitive(expansionRate)
            }
            
            if let treasuryGrowthRate = value[11] as? [Int] {
                protocolParamUpdate.treasuryGrowthRate = try UnitInterval.fromPrimitive(treasuryGrowthRate)
            }
            
            if let minPoolCost = Coin(exactly: value[12] as! UInt64) {
                protocolParamUpdate.minPoolCost = minPoolCost
            }
            
            if let adaPerUtxoByte = Coin(exactly: value[13] as! UInt64) {
                protocolParamUpdate.adaPerUtxoByte = adaPerUtxoByte
            }
            
            if let costModels = value[14] as? [Int: Any] {
                protocolParamUpdate.costModels = try CostModels.fromPrimitive(costModels)
            }
            
            if let executionCosts = value[15] as? [Int: Any] {
                protocolParamUpdate.executionCosts = try ExUnitPrices.fromPrimitive(executionCosts)
            }
            
            if let maxTxExUnits = value[16] as? [Int] {
                protocolParamUpdate.maxTxExUnits = try ExUnits.fromPrimitive(maxTxExUnits)
            }
            
            if let maxBlockExUnits = value[17] as? [Int] {
                protocolParamUpdate.maxBlockExUnits = try ExUnits.fromPrimitive(maxBlockExUnits)
            }
            
            if let maxValueSize = value[18] as? UInt32 {
                protocolParamUpdate.maxValueSize = maxValueSize
            }
            
            if let collateralPercentage = value[19] as? UInt16 {
                protocolParamUpdate.collateralPercentage = collateralPercentage
            }
            
            if let maxCollateralInputs = value[20] as? UInt16 {
                protocolParamUpdate.maxCollateralInputs = maxCollateralInputs
            }
            
            if let poolVotingThresholds = value[21] as? [Int] {
                protocolParamUpdate.poolVotingThresholds = try PoolVotingThresholds.fromPrimitive(poolVotingThresholds)
            }
            
            if let drepVotingThresholds = value[22] as? [Int] {
                protocolParamUpdate.drepVotingThresholds = try DrepVotingThresholds.fromPrimitive(drepVotingThresholds)
            }
            
            if let minCommitteeSize = value[23] as? UInt16 {
                protocolParamUpdate.minCommitteeSize = minCommitteeSize
            }
            
            if let committeeTermLimit = value[24] as? UInt32 {
                protocolParamUpdate.committeeTermLimit = EpochInterval(exactly: committeeTermLimit)
            }
            
            if let governanceActionValidityPeriod = value[25] as? UInt32 {
                protocolParamUpdate.governanceActionValidityPeriod = EpochInterval(exactly: governanceActionValidityPeriod)
            }
            
            if let governanceActionDeposit = Coin(exactly: value[26] as! UInt64) {
                protocolParamUpdate.governanceActionDeposit = governanceActionDeposit
            }
            
            if let drepDeposit = Coin(exactly: value[28] as! UInt64) {
                protocolParamUpdate.drepDeposit = drepDeposit
            }
            
            if let drepInactivityPeriod = value[29] as? UInt32 {
                protocolParamUpdate.drepInactivityPeriod = EpochInterval(exactly: drepInactivityPeriod)
            }
            
            if let minFeeRefScriptCoinsPerByte = value[30] as? [Int] {
                protocolParamUpdate.minFeeRefScriptCoinsPerByte = try NonNegativeInterval.fromPrimitive(minFeeRefScriptCoinsPerByte)
            }
            
            return protocolParamUpdate as! T
        } else {
            throw CardanoCoreError
                .valueError(
                    "Invalid value type for ProtocolParamUpdate: \(value)"
                )
        }
        
    }
}
