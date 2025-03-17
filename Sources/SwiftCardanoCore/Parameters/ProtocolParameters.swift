import Foundation

public struct ProtocolParameters: JSONLoadable {
    public let collateralPercentage: Int
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
    
    public init(collateralPercentage: Int,
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
}

public struct ProtocolParametersCostModels: Codable, Equatable, Hashable {
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
            case 1:
                return PlutusV1
            case 2:
                return PlutusV2
            case 3:
                return PlutusV3
            default:
                return nil
        }
    }
}

public struct DRepVotingThresholds: Codable, Equatable, Hashable {
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

public struct MinReferenceScriptsSize: Codable, Equatable, Hashable {
    public let base: Double?
    public let multiplier: Double?
    public let range: Double?
    
    public init(base: Double?, multiplier: Double?, range: Double?) {
        self.base = base
        self.multiplier = multiplier
        self.range = range
    }
}

public struct ExecutionUnitPrices: Codable, Equatable, Hashable {
    public let priceMemory: Double
    public let priceSteps: Double
    
    public init(priceMemory: Double, priceSteps: Double) {
        self.priceMemory = priceMemory
        self.priceSteps = priceSteps
    }
}

public struct ProtocolParametersExecutionUnits: Codable, Equatable, Hashable {
    public let memory: Int
    public let steps: Int64
    
    public init(memory: Int, steps: Int64) {
        self.memory = memory
        self.steps = steps
    }
}

public struct ProtocolParametersPoolVotingThresholds: Codable, Equatable, Hashable {
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

public struct ProtocolParametersProtocolVersion: Codable, Equatable, Hashable {
    public let major: Int
    public let minor: Int
    
    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
}
