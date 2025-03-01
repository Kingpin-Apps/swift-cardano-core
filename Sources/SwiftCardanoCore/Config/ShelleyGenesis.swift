import Foundation

public struct ShelleyGenesis: JSONLoadable {
    public let activeSlotsCoeff: Double
    public let protocolParams: ProtocolParams
    public let genDelegs: [String: GenDelegation]
    public let updateQuorum: Int
    public let networkId: String
    public let initialFunds: [String: Int]
    public let maxLovelaceSupply: UInt64
    public let networkMagic: UInt32
    public let epochLength: UInt32
    public let systemStart: String
    public let slotsPerKESPeriod: UInt32
    public let slotLength: UInt32
    public let maxKESEvolutions: UInt32
    public let securityParam: UInt32
}

public struct ProtocolParams: Codable, Equatable, Hashable {
    public struct ProtocolVersion: Codable, Equatable, Hashable {
        public let minor: Int
        public let major: Int
    }
    
    public struct ExtraEntropy: Codable, Equatable, Hashable {
        public let tag: String
    }
    
    public let protocolVersion: ProtocolVersion
    public let decentralisationParam: Double
    public let eMax: Int
    public let extraEntropy: ExtraEntropy
    public let maxTxSize: UInt32
    public let maxBlockBodySize: UInt32
    public let maxBlockHeaderSize: UInt32
    public let minFeeA: UInt32
    public let minFeeB: UInt32
    public let minUTxOValue: UInt64
    public let poolDeposit: UInt64
    public let minPoolCost: UInt64
    public let keyDeposit: UInt64
    public let nOpt: Int
    public let rho: Double
    public let tau: Double
    public let a0: Double
}

public struct GenDelegation: Codable, Equatable, Hashable {
    public let delegate: String
    public let vrf: String
} 
