import Foundation
import OrderedCollections


/// A proposal to pay out of the treasury: `treasury_withdrawals_action = (2, { reward_account => coin }, policy_hash / nil)`.
///
/// It has no previous-action id.
public struct TreasuryWithdrawalsAction: GovernanceAction {
    public static var code: GovActionCode { get { .treasuryWithdrawalsAction } }
    
    /// The amount, in lovelace, to pay to each reward account.
    public let withdrawals: [RewardAccount: Coin] // reward_account => coin
    /// The hash of the guardrails script, or `nil` when there is none.
    public let policyHash: PolicyHash?
    
    /// Creates a treasury withdrawals action.
    /// - Parameters:
    ///   - withdrawals: The amount, in lovelace, to pay to each reward account.
    ///   - policyHash: The hash of the guardrails script, or `nil` for none.
    public init(withdrawals: [RewardAccount: Coin], policyHash: PolicyHash?) {
        self.withdrawals = withdrawals
        self.policyHash = policyHash
    }
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid TreasuryWithdrawalsAction primitive")
        }
        let code = try elements[0].integer("TreasuryWithdrawalsAction code", as: Int.self)
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
            let coinValue = try valuePrimitive.integer("TreasuryWithdrawalsAction withdrawal", as: Coin.self)
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
        // A Swift `Dictionary` iterates in a different order from one process
        // to the next, so the accounts are written sorted by their bytes:
        // the same action always encodes, and hashes, the same way.
        var withdrawalsDict = OrderedDictionary<Primitive, Primitive>()
        for (rewardAccount, coin) in withdrawals.sorted(by: {
            $0.key.lexicographicallyPrecedes($1.key)
        }) {
            withdrawalsDict[.bytes(rewardAccount)] = .integer(coin)
        }

        return .list([
            .int(Int64(Self.code.rawValue)),
            .orderedDict(withdrawalsDict),
            policyHash?.toPrimitive() ?? .null
        ])
    }
}
