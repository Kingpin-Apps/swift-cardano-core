import Foundation

public struct ConwayGenesis: JSONLoadable {
    public let poolVotingThresholds: ConwayGenesisPoolVotingThresholds
    public let dRepVotingThresholds: ConwayGenesisDRepVotingThresholds
    public let committeeMinSize: Int
    public let committeeMaxTermLength: Int
    public let govActionLifetime: Int
    public let govActionDeposit: UInt64
    public let dRepDeposit: UInt64
    public let dRepActivity: Int
    public let minFeeRefScriptCostPerByte: Int
    public let plutusV3CostModel: [Int]
    public let constitution: ConwayGenesisConstitution
    public let committee: Committee
}

public struct ConwayGenesisPoolVotingThresholds: Codable, Equatable, Hashable {
    public let committeeNormal: Double
    public let committeeNoConfidence: Double
    public let hardForkInitiation: Double
    public let motionNoConfidence: Double
    public let ppSecurityGroup: Double
}

public struct ConwayGenesisDRepVotingThresholds: Codable, Equatable, Hashable {
    public let motionNoConfidence: Double
    public let committeeNormal: Double
    public let committeeNoConfidence: Double
    public let updateToConstitution: Double
    public let hardForkInitiation: Double
    public let ppNetworkGroup: Double
    public let ppEconomicGroup: Double
    public let ppTechnicalGroup: Double
    public let ppGovGroup: Double
    public let treasuryWithdrawal: Double
}

public struct ConwayGenesisConstitution: Codable, Equatable, Hashable {
    public let anchor: ConwayGenesisAnchor
    public let script: String
}

public struct ConwayGenesisAnchor: Codable, Equatable, Hashable {
    public let dataHash: String
    public let url: String
}
