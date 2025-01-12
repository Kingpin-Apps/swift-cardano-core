import Foundation

enum GovAction {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
}

struct GovActionID: ArrayCBORSerializable, Hashable {
    let transactionID: TransactionId
    let govActionIndex: UInt16
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct ParameterChangeAction: ArrayCBORSerializable {
    public var code: Int { get { return 0 } }
    
    let id: GovActionID?
    let protocolParamUpdate: ProtocolParamUpdate
    let policyHash: PolicyHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct HardForkInitiationAction: ArrayCBORSerializable {
    public var code: Int { get { return 1 } }
    
    let id: GovActionID?
    let protocolVersion: ProtocolVersion
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct TreasuryWithdrawalsAction: ArrayCBORSerializable {
    public var code: Int { get { return 2 } }
    
    let withdrawals: [RewardAccount: Coin] // reward_account => coin
    let policyHash: PolicyHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct NoConfidence: ArrayCBORSerializable {
    public var code: Int { get { return 3 } }
    
    let id: GovActionID
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct UpdateCommittee: ArrayCBORSerializable  {
    public var code: Int { get { return 4 } }
    
    let id: GovActionID?
    let coldCredentials: Set<CommitteeColdCredential>
    let credentialEpochs: [CommitteeColdCredential: UInt64] // committee_cold_credential => epoch_no
    let interval: UnitInterval
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct NewConstitution: ArrayCBORSerializable  {
    public var code: Int { get { return 5 } }
    
    let id: GovActionID
    let constitution: Constitution
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct InfoAction {
    let value: Int = 6
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
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
        <#code#>
    }
}

struct DrepVotingThresholds {
    var thresholds: [UnitInterval]

    init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
}

struct ProtocolParamUpdate {
    var minFeeA: Coin?
    var minFeeB: Coin?
    var maxBlockBodySize: UInt32?
    var maxTransactionSize: UInt32?
    var maxBlockHeaderSize: UInt16?
    var keyDeposit: Coin?
    var poolDeposit: Coin?
    var maximumEpoch: EpochInterval?
    var nOpt: UInt16?
    var poolPledgeInfluence: NonNegativeInterval?
    var expansionRate: UnitInterval?
    var treasuryGrowthRate: UnitInterval?
    var minPoolCost: Coin?
    var adaPerUtxoByte: Coin?
    var costModels: CostModels?
    var executionCosts: ExUnitPrices?
    var maxTxExUnits: ExUnits?
    var maxBlockExUnits: ExUnits?
    var maxValueSize: UInt32?
    var collateralPercentage: UInt16?
    var maxCollateralInputs: UInt16?
    var poolVotingThresholds: PoolVotingThresholds?
    var drepVotingThresholds: DrepVotingThresholds?
    var minCommitteeSize: UInt16?
    var committeeTermLimit: EpochInterval?
    var governanceActionValidityPeriod: EpochInterval?
    var governanceActionDeposit: Coin?
    var drepDeposit: Coin?
    var drepInactivityPeriod: EpochInterval?
    var minFeeRefScriptCoinsPerByte: NonNegativeInterval?
}


struct ExUnitPrices {
    var memPrice: NonNegativeInterval
    var stepPrice: NonNegativeInterval
}

struct ExUnits {
    var mem: UInt
    var steps: UInt
}

struct Constitution {
    let anchor: Anchor
    let scriptHash: ScriptHash?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct ProposalProcedure {
    let deposit: Coin
    let rewardAccount: RewardAccount
    let govAction: GovAction
    let anchor: Anchor
}

struct ProposalProcedures {
    var procedures: NonEmptySet<ProposalProcedure>
}
