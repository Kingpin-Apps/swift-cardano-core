import Foundation

enum GovAction: ArrayCBORSerializable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any] else {
            throw CardanoCoreError.deserializeError("Invalid GovActionType data: \(value)")
        }
        
        let code = list[0] as! UInt8
        switch code {
            case 0:
                let action: ParameterChangeAction = try ParameterChangeAction.fromPrimitive(list)
                return action as! T
            case 1:
                let action: HardForkInitiationAction = try HardForkInitiationAction.fromPrimitive(list)
                return action as! T
            case 2:
                let action: TreasuryWithdrawalsAction =  try TreasuryWithdrawalsAction.fromPrimitive(list)
                return action as! T
            case 3:
                let action: NoConfidence =  try NoConfidence.fromPrimitive(list)
                return action as! T
            case 4:
                let action: UpdateCommittee =  try UpdateCommittee.fromPrimitive(list)
                return action as! T
            case 5:
                let action: NewConstitution =  try NewConstitution.fromPrimitive(list)
                return action as! T
            case 6:
                let action: InfoAction =  try InfoAction.fromPrimitive(list)
                return action as! T
            default:
                throw CardanoCoreError.deserializeError("Invalid GovAction code: \(code)")
        }
    }
}

struct GovActionID: ArrayCBORSerializable, Hashable {
    let transactionID: TransactionId
    let govActionIndex: UInt16
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var transactionID: Data
        var govActionIndex: UInt16
        
        if let list = value as? [Any] {
            transactionID = list[0] as! Data
            govActionIndex = list[1] as! UInt16
        } else if let tuple = value as? (Any, Any) {
            transactionID = tuple.0 as! Data
            govActionIndex = tuple.1 as! UInt16
        } else {
            throw CardanoCoreError.deserializeError("Invalid GovActionID data: \(value)")
        }
        
        return GovActionID(
            transactionID: try TransactionId(payload: transactionID),
            govActionIndex: govActionIndex
        ) as! T
    }
}

struct PoolVotingThresholds: ArrayCBORSerializable {
    var committeeNoConfidence: UnitInterval?
    var committeeNormal: UnitInterval?
    var hardForkInitiation: UnitInterval?
    var motionNoConfidence: UnitInterval?
    var ppSecurityGroup: UnitInterval?
    
    enum CodingKeys: String, CodingKey {
        case committeeNoConfidence = "committee_no_confidence"
        case committeeNormal = "committee_normal"
        case hardForkInitiation = "hard_fork_initiation"
        case motionNoConfidence = "motion_no_confidence"
        case ppSecurityGroup = "pp_security_group"
    }
    
    var thresholds: [UnitInterval]

    init(from thresholds: [UnitInterval]) {
        precondition(thresholds.count == 5, "There must be exactly 5 unit intervals")
        self.thresholds = thresholds
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 5 else {
            throw CardanoCoreError.deserializeError("Invalid PoolVotingThresholds data: \(value)")
        }
        
        var thresholds: [UnitInterval] = []
        for item in list {
            thresholds.append(try UnitInterval.fromPrimitive(item))
        }
        
        return PoolVotingThresholds(from: thresholds) as! T
    }
}

struct DrepVotingThresholds: ArrayCBORSerializable  {
    var thresholds: [UnitInterval]

    init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 10 else {
            throw CardanoCoreError.deserializeError("Invalid DrepVotingThresholds data: \(value)")
        }
        
        var thresholds: [UnitInterval] = []
        for item in list {
            thresholds.append(try UnitInterval.fromPrimitive(item))
        }
        
        return DrepVotingThresholds(thresholds: thresholds) as! T
    }
}


struct ExUnitPrices: ArrayCBORSerializable {
    var memPrice: NonNegativeInterval
    var stepPrice: NonNegativeInterval
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ExUnitPrices data: \(value)")
        }
        
        let memPrice: NonNegativeInterval = try NonNegativeInterval.fromPrimitive(list[0])
        let stepPrice: NonNegativeInterval = try NonNegativeInterval.fromPrimitive(list[1])
        
        return ExUnitPrices(memPrice: memPrice, stepPrice: stepPrice) as! T
    }

}

struct ExUnits: ArrayCBORSerializable {
    var mem: UInt
    var steps: UInt
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ExUnits data: \(value)")
        }
        let mem = list[0] as! UInt
        let steps = list[1] as! UInt
        
        return ExUnits(mem: mem, steps: steps) as! T
    }

}

struct Constitution: ArrayCBORSerializable {
    let anchor: Anchor
    let scriptHash: ScriptHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid Constitution data: \(value)")
        }
        
        let anchor: Anchor = try Anchor.fromPrimitive(list[0])
        let scriptHash: ScriptHash = try ScriptHash.fromPrimitive(list[1])
        
        return Constitution(anchor: anchor, scriptHash: scriptHash) as! T
    }
}

struct ProposalProcedure: ArrayCBORSerializable {
    let deposit: Coin
    let rewardAccount: RewardAccount
    let govAction: GovAction
    let anchor: Anchor
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 4 else {
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure data: \(value)")
        }
        
        let deposit: Coin = Coin(list[0] as! UInt64)
        let rewardAccount = list[1] as! RewardAccount
        let govAction: GovAction = try GovAction.fromPrimitive(list[2] as! Data)
        let anchor: Anchor = try Anchor.fromPrimitive(list[3])
        
        return ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        ) as! T
    }
}

struct ProposalProcedures {
    var procedures: NonEmptySet<ProposalProcedure>
}
