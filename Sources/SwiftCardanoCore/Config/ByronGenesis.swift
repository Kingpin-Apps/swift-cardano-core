import Foundation

/// Represents the Byron genesis configuration
public struct ByronGenesis: JSONLoadable {
    /// Distribution of Ada vouchers
    public let avvmDistr: [String: String]
    /// Block version data configuration
    public let blockVersionData: BlockVersionData
    /// FTS seed value
    public let ftsSeed: String?
    /// Protocol constants
    public let protocolConsts: ProtocolConsts
    /// Genesis start time
    public let startTime: Int
    /// Boot stakeholders
    public let bootStakeholders: [String: Int]
    /// Heavy delegation certificates
    public let heavyDelegation: [String: HeavyDelegation]
    /// Non-AVVM balances
    public let nonAvvmBalances: [String: String]
    /// VSS certificates
    public let vssCerts: [String: VSSCert]?
}

/// Block version data configuration
public struct BlockVersionData: Codable, Equatable, Hashable {
    public let heavyDelThd: String
    public let maxBlockSize: String
    public let maxHeaderSize: String
    public let maxProposalSize: String
    public let maxTxSize: String
    public let mpcThd: String
    public let scriptVersion: Int
    public let slotDuration: String
    public let softforkRule: SoftforkRule
    public let txFeePolicy: TxFeePolicy
    public let unlockStakeEpoch: String
    public let updateImplicit: String
    public let updateProposalThd: String
    public let updateVoteThd: String
}

/// Softfork rule configuration
public struct SoftforkRule: Codable, Equatable, Hashable {
    public let initThd: String
    public let minThd: String
    public let thdDecrement: String
}

/// Transaction fee policy
public struct TxFeePolicy: Codable, Equatable, Hashable {
    public let multiplier: String
    public let summand: String
}

/// Protocol constants
public struct ProtocolConsts: Codable, Equatable, Hashable {
    public let k: Int
    public let protocolMagic: Int
    public let vssMaxTTL: Int?
    public let vssMinTTL: Int?
}

/// Heavy delegation certificate
public struct HeavyDelegation: Codable, Equatable, Hashable {
    public let cert: String
    public let delegatePk: String
    public let issuerPk: String
    public let omega: Int
}

/// VSS certificate
public struct VSSCert: Codable, Equatable, Hashable {
    public let expiryEpoch: Int
    public let signature: String
    public let signingKey: String
    public let vssKey: String
}

