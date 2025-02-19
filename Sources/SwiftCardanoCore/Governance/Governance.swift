import Foundation

enum GovActionCode: Int, Codable {
    case parameterChangeAction = 0
    case hardForkInitiationAction = 1
    case treasuryWithdrawalsAction = 2
    case noConfidence = 3
    case updateCommittee = 4
    case newConstitution = 5
    case infoAction = 6
}

protocol GovernanceAction: Codable, Hashable, Equatable {
    static var code: GovActionCode { get }
}

enum GovAction: Codable, Hashable, Equatable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
}

struct GovActionID: Codable, Hashable, Equatable {
    let transactionID: TransactionId
    let govActionIndex: UInt16
    
    init(transactionID: TransactionId, govActionIndex: UInt16) {
        self.transactionID = transactionID
        self.govActionIndex = govActionIndex
    }
    
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
}

struct PoolVotingThresholds: Codable, Hashable, Equatable {
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
    
    init(committeeNoConfidence: UnitInterval, committeeNormal: UnitInterval, hardForkInitiation: UnitInterval, motionNoConfidence: UnitInterval, ppSecurityGroup: UnitInterval) {
        self.committeeNoConfidence = committeeNoConfidence
        self.committeeNormal = committeeNormal
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppSecurityGroup = ppSecurityGroup
        
        self.thresholds = [
            committeeNoConfidence,
            committeeNormal,
            hardForkInitiation,
            motionNoConfidence,
            ppSecurityGroup
        ]
    }
        

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
}

struct DrepVotingThresholds: Codable, Hashable, Equatable  {
    var thresholds: [UnitInterval]

    init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        thresholds = try container.decode([UnitInterval].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try thresholds.forEach { try container.encode($0) }
    }
}

struct Constitution: Codable, Hashable, Equatable {
    let anchor: Anchor
    let scriptHash: ScriptHash?
    
    init(anchor: Anchor, scriptHash: ScriptHash?) {
        self.anchor = anchor
        self.scriptHash = scriptHash
    }
    
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
}
