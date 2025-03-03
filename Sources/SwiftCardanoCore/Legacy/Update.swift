import Foundation

public struct Update: Codable, Equatable, Hashable {
    public let proposedprotocolParamUpdates: ProposedProtocolParamUpdates
    public let epoch: EpochNumber
}

public struct ProposedProtocolParamUpdates: Codable, Equatable, Hashable {
    public let data: [GenesisHash: ProtocolParamUpdate]
}
