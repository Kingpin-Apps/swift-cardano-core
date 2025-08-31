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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 3,
              case let .int(code) = elements[0],
              code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction primitive")
        }
        
        // Parse withdrawals dictionary
        guard case let .dict(withdrawalsDict) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid withdrawals in TreasuryWithdrawalsAction")
        }
        
        var withdrawals: [RewardAccount: Coin] = [:]
        for (keyPrimitive, valuePrimitive) in withdrawalsDict {
            
            guard case let .bytes(rewardsValue) = keyPrimitive  else {
                throw CardanoCoreError.deserializeError("Invalid reward account key in withdrawals")
            }
            
            guard case let .int(coinValue) = valuePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid coin value in withdrawals")
            }
            
            let rewardAccount = RewardAccount(rewardsValue)
            let coin = Coin(Int(coinValue))
            withdrawals[rewardAccount] = coin
        }
        self.withdrawals = withdrawals
        
        // Parse policy hash (optional)
        if elements[2] == .null {
            self.policyHash = nil
        } else {
            self.policyHash = try PolicyHash(from: elements[2])
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        // Convert withdrawals dictionary to primitive
        var withdrawalsDict: [Primitive: Primitive] = [:]
        for (rewardAccount, coin) in withdrawals {
            withdrawalsDict[.bytes(rewardAccount)] = .int(Int(coin))
        }
        
        return .list([
            .int(Self.code.rawValue),
            .dict(withdrawalsDict),
            policyHash?.toPrimitive() ?? .null
        ])
    }
}
