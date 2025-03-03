import Foundation


public struct TreasuryWithdrawalsAction: GovernanceAction {
    public static var code: GovActionCode { get { .treasuryWithdrawalsAction } }
    
    public let withdrawals: [RewardAccount: Coin] // reward_account => coin
    public let policyHash: PolicyHash?
    
    public init(withdrawals: [RewardAccount: Coin], policyHash: PolicyHash?) {
        self.withdrawals = withdrawals
        self.policyHash = policyHash
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction type: \(code)")
        }
        
        withdrawals = try container.decode([RewardAccount: Coin].self)
        policyHash = try container.decode(PolicyHash.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(withdrawals)
        try container.encode(policyHash)
    }
}
