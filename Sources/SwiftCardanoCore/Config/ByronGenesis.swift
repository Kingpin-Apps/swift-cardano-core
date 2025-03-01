import Foundation

/// Represents the Byron genesis configuration
struct ByronGenesis: ConfigFile {
    /// Distribution of Ada vouchers
    let avvmDistr: [String: String]
    /// Block version data configuration
    let blockVersionData: BlockVersionData
    /// FTS seed value
    let ftsSeed: String
    /// Protocol constants
    let protocolConsts: ProtocolConsts
    /// Genesis start time
    let startTime: Int
    /// Boot stakeholders
    let bootStakeholders: [String: Int]
    /// Heavy delegation certificates
    let heavyDelegation: [String: HeavyDelegation]
    /// Non-AVVM balances
    let nonAvvmBalances: [String: String]
    /// VSS certificates
    let vssCerts: [String: VSSCert]
}

/// Block version data configuration
struct BlockVersionData: Codable, Equatable, Hashable {
    let heavyDelThd: String
    let maxBlockSize: String
    let maxHeaderSize: String
    let maxProposalSize: String
    let maxTxSize: String
    let mpcThd: String
    let scriptVersion: Int
    let slotDuration: String
    let softforkRule: SoftforkRule
    let txFeePolicy: TxFeePolicy
    let unlockStakeEpoch: String
    let updateImplicit: String
    let updateProposalThd: String
    let updateVoteThd: String
}

/// Softfork rule configuration
struct SoftforkRule: Codable, Equatable, Hashable {
    let initThd: String
    let minThd: String
    let thdDecrement: String
}

/// Transaction fee policy
struct TxFeePolicy: Codable, Equatable, Hashable {
    let multiplier: String
    let summand: String
}

/// Protocol constants
struct ProtocolConsts: Codable, Equatable, Hashable {
    let k: Int
    let protocolMagic: Int
    let vssMaxTTL: Int
    let vssMinTTL: Int
}

/// Heavy delegation certificate
struct HeavyDelegation: Codable, Equatable, Hashable {
    let cert: String
    let delegatePk: String
    let issuerPk: String
    let omega: Int
}

/// VSS certificate
struct VSSCert: Codable, Equatable, Hashable {
    let expiryEpoch: Int
    let signature: String
    let signingKey: String
    let vssKey: String
}

