import Foundation

/// Stake address info model class
public struct StakeAddressInfo: Codable, Equatable, Sendable {
    
    /// Field indicating if the stake address is active
    public let active: Bool?
    
    /// The epoch in which the stake address became active
    public let activeEpoch: Int?
    
    /// Stake address
    public let address: String
    
    /// Governance Action Deposits
    public let govActionDeposits: [String:UInt64]?
    
    /// Reward account balance
    public let rewardAccountBalance: Int
    
    /// Stake delegation pool ID
    public let stakeDelegation: PoolOperator?
    
    /// StakeRegistration deposit
    public let stakeRegistrationDeposit: Int?
    
    /// Vote delegation ID
    public let voteDelegation: DRep?
    
    /// Custom coding keys to map multiple alias names from JSON
    private enum CodingKeys: String, CodingKey {
        case active
        case activeEpoch
        case address
        case govActionDeposits
        case rewardAccountBalance
        case stakeDelegation
        case stakeRegistrationDeposit
        case voteDelegation
    }
    
    public init(
        active: Bool = true,
        activeEpoch: Int? = nil,
        address: String,
        govActionDeposits: [String:UInt64]? = nil,
        rewardAccountBalance: Int,
        stakeDelegation: PoolOperator? = nil,
        stakeRegistrationDeposit: Int? = nil,
        voteDelegation: DRep? = nil
    ) {
        self.active = active
        self.activeEpoch = activeEpoch
        self.address = address
        self.govActionDeposits = govActionDeposits
        self.rewardAccountBalance = rewardAccountBalance
        self.stakeDelegation = stakeDelegation
        self.stakeRegistrationDeposit = stakeRegistrationDeposit
        self.voteDelegation = voteDelegation
    }
    
    /// Decoding with multiple alias support
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.active = try container
            .decodeIfPresent(Bool.self, forKey: .active)
        
        self.activeEpoch = try container
            .decodeIfPresent(Int.self, forKey: .activeEpoch)
        
        self.address = try container
            .decodeIfPresent(String.self, forKey: .address)!
        self.govActionDeposits = try container
            .decodeIfPresent(
                [String:UInt64].self,
                forKey: .govActionDeposits
            )
        self.stakeRegistrationDeposit = try container.decodeIfPresent(Int.self, forKey: .stakeRegistrationDeposit)
        self.rewardAccountBalance = try container.decodeIfPresent(Int.self, forKey: .rewardAccountBalance) ?? 0
        self.stakeDelegation = try? container.decodeIfPresent(PoolOperator.self, forKey: .stakeDelegation)
        self.voteDelegation = try? container.decodeIfPresent(DRep.self, forKey: .voteDelegation)
    }
    
    /// Encoding with multiple alias support
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(activeEpoch, forKey: .activeEpoch)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(govActionDeposits, forKey: .govActionDeposits)
        try container.encode(stakeRegistrationDeposit, forKey: .stakeRegistrationDeposit)
        try container.encode(rewardAccountBalance, forKey: .rewardAccountBalance)
        try container.encodeIfPresent(stakeDelegation, forKey: .stakeDelegation)
        try container.encodeIfPresent(voteDelegation, forKey: .voteDelegation)
    }
}

