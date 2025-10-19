import Foundation

public enum GovernanceKeyType: Int, Sendable {
    case ccHot = 0b0000
    case ccCold = 0b0001
    case drep = 0b0010
}

public enum GovernanceCredentialType: Int, Sendable {
    case keyHash = 0b0010
    case scriptHash = 0b0011
}

public enum GovActionCode: Int, Codable {
    case parameterChangeAction = 0
    case hardForkInitiationAction = 1
    case treasuryWithdrawalsAction = 2
    case noConfidence = 3
    case updateCommittee = 4
    case newConstitution = 5
    case infoAction = 6
}

public protocol GovernanceAction: CBORSerializable, Hashable, Equatable {
    static var code: GovActionCode { get }
}

public enum GovAction: Codable, Hashable, Equatable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
}

public struct GovActionID: CBORSerializable, Hashable, Equatable {
    public let transactionID: TransactionId
    public let govActionIndex: UInt16
    
    public init(transactionID: TransactionId, govActionIndex: UInt16) {
        self.transactionID = transactionID
        self.govActionIndex = govActionIndex
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionID = try container.decode(TransactionId.self)
        govActionIndex = try container.decode(UInt16.self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid GovActionID type")
        }
        self.transactionID = try TransactionId(from: primitive[0])
        
        guard case let .uint(govActionIndex) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid GovActionID type")
        }
        self.govActionIndex = UInt16(govActionIndex)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionID)
        try container.encode(govActionIndex)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .string(transactionID.payload.toHex),
            .uint(UInt(govActionIndex))
        ])
    }
}

public struct PoolVotingThresholds: CBORSerializable, Hashable, Equatable {
    public var committeeNoConfidence: UnitInterval?
    public var committeeNormal: UnitInterval?
    public var hardForkInitiation: UnitInterval?
    public var motionNoConfidence: UnitInterval?
    public var ppSecurityGroup: UnitInterval?
    
    enum CodingKeys: String, CodingKey {
        case committeeNoConfidence = "committee_no_confidence"
        case committeeNormal = "committee_normal"
        case hardForkInitiation = "hard_fork_initiation"
        case motionNoConfidence = "motion_no_confidence"
        case ppSecurityGroup = "pp_security_group"
    }
    
    public var thresholds: [UnitInterval]
    
    public init(committeeNoConfidence: UnitInterval, committeeNormal: UnitInterval, hardForkInitiation: UnitInterval, motionNoConfidence: UnitInterval, ppSecurityGroup: UnitInterval) {
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
        

    public init(from thresholds: [UnitInterval]) {
        precondition(thresholds.count == 5, "There must be exactly 5 unit intervals")
        self.thresholds = thresholds
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 5 else {
            throw CardanoCoreError.deserializeError("Invalid PoolVotingThresholds type")
        }
        self.committeeNoConfidence = try UnitInterval(from: primitive[0])
        self.committeeNormal = try UnitInterval(from: primitive[1])
        self.hardForkInitiation = try UnitInterval(from: primitive[2])
        self.motionNoConfidence = try UnitInterval(from: primitive[3])
        self.ppSecurityGroup = try UnitInterval(from: primitive[4])
        self.thresholds = [
            committeeNoConfidence!,
            committeeNormal!,
            hardForkInitiation!,
            motionNoConfidence!,
            ppSecurityGroup!
        ]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(committeeNoConfidence)
        try container.encode(committeeNormal)
        try container.encode(hardForkInitiation)
        try container.encode(motionNoConfidence)
        try container.encode(ppSecurityGroup)
    }
    
    public func toPrimitive() throws -> Primitive {
        var list: [Primitive] = []
        if let committeeNoConfidence = committeeNoConfidence {
            list.append(try committeeNoConfidence.toPrimitive())
        } else {
            list.append(.null)
        }
        if let committeeNormal = committeeNormal {
            list.append(try committeeNormal.toPrimitive())
        } else {
            list.append(.null)
        }
        if let hardForkInitiation = hardForkInitiation {
            list.append(try hardForkInitiation.toPrimitive())
        } else {
            list.append(.null)
        }
        if let motionNoConfidence = motionNoConfidence {
            list.append(try motionNoConfidence.toPrimitive())
        } else {
            list.append(.null)
        }
        if let ppSecurityGroup = ppSecurityGroup {
            list.append(try ppSecurityGroup.toPrimitive())
        } else {
            list.append(.null)
        }
        return .list(list)
    }

}

public struct DrepVotingThresholds: CBORSerializable, Hashable, Equatable  {
    public var thresholds: [UnitInterval]

    public init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        thresholds = try container.decode([UnitInterval].self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 10 else {
            throw CardanoCoreError.deserializeError("Invalid DrepVotingThresholds type")
        }
        self.thresholds = try primitive.map { try UnitInterval(from: $0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try thresholds.forEach { try container.encode($0) }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list(try thresholds.map { try $0.toPrimitive() })
    }
}

public struct Constitution: CBORSerializable, Hashable, Equatable {
    public let anchor: Anchor
    public let scriptHash: ScriptHash?
    
    public init(anchor: Anchor, scriptHash: ScriptHash?) {
        self.anchor = anchor
        self.scriptHash = scriptHash
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        anchor = try container.decode(Anchor.self)
        scriptHash = try container.decode(ScriptHash.self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid Constitution type")
        }
        self.anchor = try Anchor(from: primitive[0])
        self.scriptHash = try ScriptHash(from: primitive[1])

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchor)
        try container.encode(scriptHash)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try anchor.toPrimitive(),
            scriptHash?.toPrimitive() ?? .null
        ])
    }
}
