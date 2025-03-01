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
    public let minFeeRefScriptCostPerByte: Int
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
}

public struct ProtocolParametersCostModels: Codable, Equatable, Hashable {
    public let PlutusV1: [Int]
    public let PlutusV2: [Int]
    public let PlutusV3: [Int]
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
}

public struct ExecutionUnitPrices: Codable, Equatable, Hashable {
    public let priceMemory: Double
    public let priceSteps: Double
}

public struct ProtocolParametersExecutionUnits: Codable, Equatable, Hashable {
    public let memory: Int
    public let steps: Int64
}

public struct ProtocolParametersPoolVotingThresholds: Codable, Equatable, Hashable {
    public let committeeNoConfidence: Double
    public let committeeNormal: Double
    public let hardForkInitiation: Double
    public let motionNoConfidence: Double
    public let ppSecurityGroup: Double
}

public struct ProtocolParametersProtocolVersion: Codable, Equatable, Hashable {
    public let major: Int
    public let minor: Int
} 
