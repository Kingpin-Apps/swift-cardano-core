import Foundation


struct TreasuryWithdrawalsAction: ArrayCBORSerializable {
    public var code: Int { get { return 2 } }
    
    let withdrawals: [RewardAccount: Coin] // reward_account => coin
    let policyHash: PolicyHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var withdrawals: [RewardAccount: Coin]
        var policyHash: Data
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            withdrawals = list[1] as! [RewardAccount: Coin]
            policyHash = list[2] as! Data
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            withdrawals = tuple.1 as! [RewardAccount: Coin]
            policyHash = tuple.2 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction data: \(value)")
        }
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction type: \(code)")
        }
        
        return TreasuryWithdrawalsAction(
            withdrawals: withdrawals,
            policyHash: try PolicyHash.fromPrimitive(policyHash)
        ) as! T
    }
}
