import Foundation


struct TreasuryWithdrawalsAction: Codable {
    public var code: Int { get { return 2 } }
    
    let withdrawals: [RewardAccount: Coin] // reward_account => coin
    let policyHash: PolicyHash?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction type: \(code)")
        }
        
        withdrawals = try container.decode([RewardAccount: Coin].self)
        policyHash = try container.decode(PolicyHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(withdrawals)
        try container.encode(policyHash)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var withdrawals: [RewardAccount: Coin]
//        var policyHash: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            withdrawals = list[1] as! [RewardAccount: Coin]
//            policyHash = list[2] as! Data
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            withdrawals = tuple.1 as! [RewardAccount: Coin]
//            policyHash = tuple.2 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction data: \(value)")
//        }
//        
//        guard code == 14 else {
//            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction type: \(code)")
//        }
//        
//        return TreasuryWithdrawalsAction(
//            withdrawals: withdrawals,
//            policyHash: try PolicyHash.fromPrimitive(policyHash)
//        ) as! T
//    }
}
