import Foundation

struct DRepVotingThresholds: Codable {
    var committeeNoConfidence: Double?
    var committeeNormal: Double?
    var hardForkInitiation: Double?
    var motionNoConfidence: Double?
    var ppEconomicGroup: Double?
    var ppGovGroup: Double?
    var ppNetworkGroup: Double?
    var ppTechnicalGroup: Double?
    var treasuryWithdrawal: Double?
    var updateToConstitution: Double?

    enum CodingKeys: String, CodingKey {
        case committeeNoConfidence = "committee_no_confidence"
        case committeeNormal = "committee_normal"
        case hardForkInitiation = "hard_fork_initiation"
        case motionNoConfidence = "motion_no_confidence"
        case ppEconomicGroup = "pp_economic_group"
        case ppGovGroup = "pp_gov_group"
        case ppNetworkGroup = "pp_network_group"
        case ppTechnicalGroup = "pp_technical_group"
        case treasuryWithdrawal = "treasury_withdrawal"
        case updateToConstitution = "update_to_constitution"
    }
}

struct ExecutionUnitPrices: Codable {
    var priceMemory: Double?
    var priceSteps: Double?

    enum CodingKeys: String, CodingKey {
        case priceMemory = "price_memory"
        case priceSteps = "price_steps"
    }
}

struct MaxExecutionUnits: Codable {
    var memory: Int?
    var steps: Int?

    enum CodingKeys: String, CodingKey {
        case memory
        case steps
    }
}

//struct PoolVotingThresholds: Codable {
//    var committeeNoConfidence: Double?
//    var committeeNormal: Double?
//    var hardForkInitiation: Double?
//    var motionNoConfidence: Double?
//    var ppSecurityGroup: Double?
//
//    enum CodingKeys: String, CodingKey {
//        case committeeNoConfidence = "committee_no_confidence"
//        case committeeNormal = "committee_normal"
//        case hardForkInitiation = "hard_fork_initiation"
//        case motionNoConfidence = "motion_no_confidence"
//        case ppSecurityGroup = "pp_security_group"
//    }
//}

//struct ProtocolVersion: Codable {
//    var major: Int?
//    var minor: Int?
//}

struct ProtocolParameters: Codable {
    var collateralPercent: Int?
    var committeeMaxTermLength: Int?
    var committeeMinSize: Int?
    var costModels: CostModels?
    var dRepActivity: Int?
    var dRepDeposit: Int?
    var dRepVotingThresholds: DRepVotingThresholds?
    var dvtMotionNoConfidence: Double?
    var dvtCommitteeNormal: Double?
    var dvtCommitteeNoConfidence: Double?
    var dvtUpdateToConstitution: Double?
    var dvtHardForkInitiation: Double?
    var dvtPPNetworkGroup: Double?
    var dvtPPEconomicGroup: Double?
    var dvtPPTechnicalGroup: Double?
    var dvtPPGovGroup: Double?
    var dvtTreasuryWithdrawal: Double?
    var executionUnitPrices: ExecutionUnitPrices?
    var govActionDeposit: Int?
    var govActionLifetime: Int?
    var maxBlockSize: Int?
    var maxBlockExecutionUnits: MaxExecutionUnits?
    var maxBlockExMem: Int?
    var maxBlockExSteps: Int?
    var maxBlockHeaderSize: Int?
    var maxCollateralInputs: Int?
    var maxReferenceScriptsSize: Int?
    var maxTxExecutionUnits: MaxExecutionUnits?
    var maxTxExMem: Int?
    var maxTxExSteps: Int?
    var maxTxSize: Int?
    var maxValSize: Int?
    var minFeeCoefficient: Int?
    var minFeeConstant: Int?
    var minFeeRefScriptCostPerByte: Int?
    var minPoolCost: Int?
    var minUtxo: Int?
    var minUtxoDepositConstant: Int?
    var minUtxoValue: Int?
    var monetaryExpansion: Double?
    var poolInfluence: Double?
    var poolRetireMaxEpoch: Int?
    var poolVotingThresholds: PoolVotingThresholds?
    var pvtMotionNoConfidence: Double?
    var pvtCommitteeNormal: Double?
    var pvtCommitteeNoConfidence: Double?
    var pvtHardForkInitiation: Double?
    var pvtPPSecurityGroup: Double?
    var protocolVersion: ProtocolVersion?
    var protocolMajorVersion: Int?
    var protocolMinorVersion: Int?
    var keyDeposit: Int?
    var poolDeposit: Int?
    var poolTargetNum: Int?
    var treasuryExpansion: Double?
    var txFeeFixed: Int?
    var txFeePerByte: Int?
    var decentralizationParam: Double?
    var extraEntropy: String?
    var priceMem: Double?
    var priceStep: Double?
    var coinsPerUtxoWord: Int?
    var coinsPerUtxoByte: Int?
    var utxoCostPerByte: Int?
    var epoch: Int?
    var nonce: String?
    var blockHash: String?

    enum CodingKeys: String, CodingKey {
        case collateralPercent = "collateral_percent"
        case committeeMaxTermLength = "committee_max_term_length"
        case committeeMinSize = "committee_min_size"
        case costModels = "cost_models"
        case dRepActivity = "d_rep_activity"
        case dRepDeposit = "d_rep_deposit"
        case dRepVotingThresholds = "d_rep_voting_thresholds"
        case dvtMotionNoConfidence = "dvt_motion_no_confidence"
        case dvtCommitteeNormal = "dvt_committee_normal"
        case dvtCommitteeNoConfidence = "dvt_committee_no_confidence"
        case dvtUpdateToConstitution = "dvt_update_to_constitution"
        case dvtHardForkInitiation = "dvt_hard_fork_initiation"
        case dvtPPNetworkGroup = "dvt_p_p_network_group"
        case dvtPPEconomicGroup = "dvt_p_p_economic_group"
        case dvtPPTechnicalGroup = "dvt_p_p_technical_group"
        case dvtPPGovGroup = "dvt_p_p_gov_group"
        case dvtTreasuryWithdrawal = "dvt_treasury_withdrawal"
        case executionUnitPrices = "execution_unit_prices"
        case govActionDeposit = "gov_action_deposit"
        case govActionLifetime = "gov_action_lifetime"
        case maxBlockSize = "max_block_size"
        case maxBlockExecutionUnits = "max_block_execution_units"
        case maxBlockExMem = "max_block_ex_mem"
        case maxBlockExSteps = "max_block_ex_steps"
        case maxBlockHeaderSize = "max_block_header_size"
        case maxCollateralInputs = "max_collateral_inputs"
        case maxReferenceScriptsSize = "max_reference_scripts_size"
        case maxTxExecutionUnits = "max_tx_execution_units"
        case maxTxExMem = "max_tx_ex_mem"
        case maxTxExSteps = "max_tx_ex_steps"
        case maxTxSize = "max_tx_size"
        case maxValSize = "max_val_size"
        case minFeeCoefficient = "min_fee_coefficient"
        case minFeeConstant = "min_fee_constant"
        case minFeeRefScriptCostPerByte = "min_fee_ref_script_cost_per_byte"
        case minPoolCost = "min_pool_cost"
        case minUtxo = "min_utxo"
        case minUtxoDepositConstant = "min_utxo_deposit_constant"
        case minUtxoValue = "min_utxo_value"
        case monetaryExpansion = "monetary_expansion"
        case poolInfluence = "pool_influence"
        case poolRetireMaxEpoch = "pool_retire_max_epoch"
        case poolVotingThresholds = "pool_voting_thresholds"
        case pvtMotionNoConfidence = "pvt_motion_no_confidence"
        case pvtCommitteeNormal = "pvt_committee_normal"
        case pvtCommitteeNoConfidence = "pvt_committee_no_confidence"
        case pvtHardForkInitiation = "pvt_hard_fork_initiation"
        case pvtPPSecurityGroup = "pvt_pp_security_group"
        case protocolVersion = "protocol_version"
        case protocolMajorVersion = "protocol_major_version"
        case protocolMinorVersion = "protocol_minor_version"
        case keyDeposit = "key_deposit"
        case poolDeposit = "pool_deposit"
        case poolTargetNum = "pool_target_num"
        case treasuryExpansion = "treasury_expansion"
        case txFeeFixed = "tx_fee_fixed"
        case txFeePerByte = "tx_fee_per_byte"
        case decentralizationParam = "decentralization_param"
        case extraEntropy = "extra_entropy"
        case priceMem = "price_mem"
        case priceStep = "price_step"
        case coinsPerUtxoWord = "coins_per_utxo_word"
        case coinsPerUtxoByte = "coins_per_utxo_byte"
        case utxoCostPerByte = "utxo_cost_per_byte"
        case epoch
        case nonce
        case blockHash = "block_hash"
    }
}
