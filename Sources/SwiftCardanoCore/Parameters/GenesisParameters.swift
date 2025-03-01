import Foundation

struct GenesisParameters: Codable {
//    var alonzoGenesis: [String: Any]?
//    var byronGenesis: [String: Any]?
//    var conwayGenesis: [String: Any]?
//    var shelleyGenesis: [String: Any]?
//    var genDelegs: [String: Any]?
//    var initialFunds: [String: Any]?
//    var staking: [String: Any]?
//    var protocolParams: [String: Any]?
    var era: String?
    var activeSlotsCoefficient: Double?
    var epochLength: Int?
    var maxKesEvolutions: Int?
    var maxLovelaceSupply: Int?
    var networkId: String?
    var networkMagic: Int?
    var securityParam: Int?
    var slotLength: Int?
    var slotsPerKesPeriod: Int?
    var systemStart: Date?
    var updateQuorum: Int?

    enum CodingKeys: String, CodingKey {
//        case alonzoGenesis
//        case byronGenesis
//        case conwayGenesis
//        case shelleyGenesis
//        case genDelegs
//        case initialFunds
//        case staking
//        case protocolParams
        case era
        case activeSlotsCoefficient
        case epochLength
        case maxKesEvolutions
        case maxLovelaceSupply
        case networkId
        case networkMagic
        case securityParam
        case slotLength
        case slotsPerKesPeriod
        case systemStart
        case updateQuorum
    }
}
