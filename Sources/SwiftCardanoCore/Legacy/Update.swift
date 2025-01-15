import Foundation

struct Update: Codable {
    let proposedprotocolParamUpdates: ProposedprotocolParamUpdates
    let epoch: EpochNumber
}

struct ProposedprotocolParamUpdates: Codable {
    let data: [GenesisHash: ProtocolParamUpdate]
}
