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
        guard case let .list(elements) = primitive, elements.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction primitive")
        }
        let code: Int
        switch elements[0] {
        case .int(let v): code = v
        case .uint(let v): code = Int(v)
        default: throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction primitive")
        }
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction primitive")
        }
        
        // Parse withdrawals dictionary (orderedDict or dict)
        let withdrawalsPairs: [(Primitive, Primitive)]
        switch elements[1] {
        case .dict(let d): withdrawalsPairs = d.map { ($0.key, $0.value) }
        case .orderedDict(let d): withdrawalsPairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid withdrawals in TreasuryWithdrawalsAction")
        }
        var withdrawals: [RewardAccount: Coin] = [:]
        for (keyPrimitive, valuePrimitive) in withdrawalsPairs {
            guard case let .bytes(rewardsValue) = keyPrimitive else {
                throw CardanoCoreError.deserializeError("Invalid reward account key in withdrawals")
            }
            let coinValue: Coin
            switch valuePrimitive {
            case .uint(let u): coinValue = Coin(u)
            case .int(let i) where i >= 0: coinValue = Coin(i)
            default:
                throw CardanoCoreError.deserializeError("Invalid coin value in withdrawals")
            }
            withdrawals[RewardAccount(rewardsValue)] = coinValue
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
