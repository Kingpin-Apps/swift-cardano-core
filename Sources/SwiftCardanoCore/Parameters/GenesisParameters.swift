import Foundation

struct GenesisParameters: Codable {
    var alonzoGenesis: [String: Any]?
    var byronGenesis: [String: Any]?
    var conwayGenesis: [String: Any]?
    var shelleyGenesis: [String: Any]?
    var era: String?
    var activeSlotsCoefficient: Double?
    var epochLength: Int?
    var genDelegs: [String: Any]?
    var initialFunds: [String: Any]?
    var maxKesEvolutions: Int?
    var maxLovelaceSupply: Int?
    var networkId: String?
    var networkMagic: Int?
    var protocolParams: [String: Any]?
    var securityParam: Int?
    var slotLength: Int?
    var slotsPerKesPeriod: Int?
    var staking: [String: Any]?
    var systemStart: Date?
    var updateQuorum: Int?

    enum CodingKeys: String, CodingKey {
        case alonzoGenesis = "alonzo_genesis"
        case byronGenesis = "byron_genesis"
        case conwayGenesis = "conway_genesis"
        case shelleyGenesis = "shelley_genesis"
        case era
        case activeSlotsCoefficient = "active_slots_coefficient"
        case epochLength = "epoch_length"
        case genDelegs = "gen_delegs"
        case initialFunds = "initial_funds"
        case maxKesEvolutions = "max_kes_evolutions"
        case maxLovelaceSupply = "max_lovelace_supply"
        case networkId = "network_id"
        case networkMagic = "network_magic"
        case protocolParams = "protocol_params"
        case securityParam = "security_param"
        case slotLength = "slot_length"
        case slotsPerKesPeriod = "slots_per_kes_period"
        case staking
        case systemStart = "system_start"
        case updateQuorum = "update_quorum"
    }
}
