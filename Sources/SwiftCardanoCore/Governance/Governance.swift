import Foundation

enum GovAction: Codable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any] else {
//            throw CardanoCoreError.deserializeError("Invalid GovActionType data: \(value)")
//        }
//        
//        let code = list[0] as! UInt8
//        switch code {
//            case 0:
//                let action: ParameterChangeAction = try ParameterChangeAction.fromPrimitive(list)
//                return action as! T
//            case 1:
//                let action: HardForkInitiationAction = try HardForkInitiationAction.fromPrimitive(list)
//                return action as! T
//            case 2:
//                let action: TreasuryWithdrawalsAction =  try TreasuryWithdrawalsAction.fromPrimitive(list)
//                return action as! T
//            case 3:
//                let action: NoConfidence =  try NoConfidence.fromPrimitive(list)
//                return action as! T
//            case 4:
//                let action: UpdateCommittee =  try UpdateCommittee.fromPrimitive(list)
//                return action as! T
//            case 5:
//                let action: NewConstitution =  try NewConstitution.fromPrimitive(list)
//                return action as! T
//            case 6:
//                let action: InfoAction =  try InfoAction.fromPrimitive(list)
//                return action as! T
//            default:
//                throw CardanoCoreError.deserializeError("Invalid GovAction code: \(code)")
//        }
//    }
}

struct GovActionID: Codable, Hashable {
    let transactionID: TransactionId
    let govActionIndex: UInt16
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionID = try container.decode(TransactionId.self)
        govActionIndex = try container.decode(UInt16.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionID)
        try container.encode(govActionIndex)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var transactionID: Data
//        var govActionIndex: UInt16
//        
//        if let list = value as? [Any] {
//            transactionID = list[0] as! Data
//            govActionIndex = list[1] as! UInt16
//        } else if let tuple = value as? (Any, Any) {
//            transactionID = tuple.0 as! Data
//            govActionIndex = tuple.1 as! UInt16
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid GovActionID data: \(value)")
//        }
//        
//        return GovActionID(
//            transactionID: try TransactionId(payload: transactionID),
//            govActionIndex: govActionIndex
//        ) as! T
//    }
}

struct PoolVotingThresholds: Codable {
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
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        committeeNoConfidence = try container.decodeIfPresent(UnitInterval.self)
        committeeNormal = try container.decodeIfPresent(UnitInterval.self)
        hardForkInitiation = try container.decodeIfPresent(UnitInterval.self)
        motionNoConfidence = try container.decodeIfPresent(UnitInterval.self)
        ppSecurityGroup = try container.decodeIfPresent(UnitInterval.self)
        
        thresholds = [
            committeeNoConfidence!,
            committeeNormal!,
            hardForkInitiation!,
            motionNoConfidence!,
            ppSecurityGroup!
        ]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(committeeNoConfidence)
        try container.encode(committeeNormal)
        try container.encode(hardForkInitiation)
        try container.encode(motionNoConfidence)
        try container.encode(ppSecurityGroup)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 5 else {
//            throw CardanoCoreError.deserializeError("Invalid PoolVotingThresholds data: \(value)")
//        }
//        
//        var thresholds: [UnitInterval] = []
//        for item in list {
//            thresholds.append(try UnitInterval.fromPrimitive(item))
//        }
//        
//        return PoolVotingThresholds(from: thresholds) as! T
//    }
}

struct DrepVotingThresholds: Codable  {
    var thresholds: [UnitInterval]

    init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        thresholds = try container.decode([UnitInterval].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try thresholds.forEach { try container.encode($0) }
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 10 else {
//            throw CardanoCoreError.deserializeError("Invalid DrepVotingThresholds data: \(value)")
//        }
//        
//        var thresholds: [UnitInterval] = []
//        for item in list {
//            thresholds.append(try UnitInterval.fromPrimitive(item))
//        }
//        
//        return DrepVotingThresholds(thresholds: thresholds) as! T
//    }
}

struct Constitution: Codable {
    let anchor: Anchor
    let scriptHash: ScriptHash?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        anchor = try container.decode(Anchor.self)
        scriptHash = try container.decode(ScriptHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchor)
        try container.encode(scriptHash)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 3 else {
//            throw CardanoCoreError.deserializeError("Invalid Constitution data: \(value)")
//        }
//        
//        let anchor: Anchor = try Anchor.fromPrimitive(list[0])
//        let scriptHash: ScriptHash = try ScriptHash.fromPrimitive(list[1])
//        
//        return Constitution(anchor: anchor, scriptHash: scriptHash) as! T
//    }
}

struct ProposalProcedure: Codable {
    let deposit: Coin
    let rewardAccount: RewardAccount
    let govAction: GovAction
    let anchor: Anchor
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        deposit = try container.decode(Coin.self)
        rewardAccount = try container.decode(RewardAccount.self)
        govAction = try container.decode(GovAction.self)
        anchor = try container.decode(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(deposit)
        try container.encode(rewardAccount)
        try container.encode(govAction)
        try container.encode(anchor)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 4 else {
//            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure data: \(value)")
//        }
//        
//        let deposit: Coin = Coin(list[0] as! UInt64)
//        let rewardAccount = list[1] as! RewardAccount
//        let govAction: GovAction = try GovAction.fromPrimitive(list[2] as! Data)
//        let anchor: Anchor = try Anchor.fromPrimitive(list[3])
//        
//        return ProposalProcedure(
//            deposit: deposit,
//            rewardAccount: rewardAccount,
//            govAction: govAction,
//            anchor: anchor
//        ) as! T
//    }
}

struct ProposalProcedures {
    var procedures: NonEmptySet<ProposalProcedure>
}
