import Foundation

public struct ConwayGenesis: JSONLoadable {
    let poolVotingThresholds: ConwayGenesisPoolVotingThresholds
    let dRepVotingThresholds: ConwayGenesisDRepVotingThresholds
    let committeeMinSize: Int
    let committeeMaxTermLength: Int
    let govActionLifetime: Int
    let govActionDeposit: UInt64
    let dRepDeposit: UInt64
    let dRepActivity: Int
    let minFeeRefScriptCostPerByte: Int
    let plutusV3CostModel: [Int]
    let constitution: ConwayGenesisConstitution
    let committee: Committee
}

struct ConwayGenesisPoolVotingThresholds: Codable, Equatable, Hashable {
    let committeeNormal: Double
    let committeeNoConfidence: Double
    let hardForkInitiation: Double
    let motionNoConfidence: Double
    let ppSecurityGroup: Double
}

struct ConwayGenesisDRepVotingThresholds: Codable, Equatable, Hashable {
    let motionNoConfidence: Double
    let committeeNormal: Double
    let committeeNoConfidence: Double
    let updateToConstitution: Double
    let hardForkInitiation: Double
    let ppNetworkGroup: Double
    let ppEconomicGroup: Double
    let ppTechnicalGroup: Double
    let ppGovGroup: Double
    let treasuryWithdrawal: Double
}

struct ConwayGenesisConstitution: Codable, Equatable, Hashable {
    let anchor: ConwayGenesisAnchor
    let script: String
}

struct ConwayGenesisAnchor: Codable, Equatable, Hashable {
    let dataHash: String
    let url: String
}

struct Committee: Codable, Equatable, Hashable {
    let members: [String: Int]
    let threshold: Threshold
}

struct Threshold: Codable, Equatable, Hashable {
    let numerator: Int
    let denominator: Int
} 
