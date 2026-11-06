import Foundation
import OrderedCollections

/// A proposal to change protocol parameters: `parameter_change_action = (0, gov_action_id / nil, protocol_param_update, policy_hash / nil)`.
public struct ParameterChangeAction: GovernanceAction {
    public static var code: GovActionCode { .parameterChangeAction }

    /// The previous parameter change action, which this one has to follow, or `nil` for none.
    public var id: GovActionID?
    /// The parameters to change and their new values.
    public let protocolParamUpdate: ProtocolParamUpdate
    /// The hash of the guardrails script, or `nil` when there is none.
    public let policyHash: PolicyHash?

    /// Creates a parameter change action.
    /// - Parameters:
    ///   - id: The previous parameter change action.
    ///   - protocolParamUpdate: The parameters to change and their new values.
    ///   - policyHash: The hash of the guardrails script, or `nil` for none.
    public init(id: GovActionID, protocolParamUpdate: ProtocolParamUpdate, policyHash: PolicyHash?)
    {
        self.id = id
        self.protocolParamUpdate = protocolParamUpdate
        self.policyHash = policyHash
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive,
            elements.count == 4
        else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }
        let code: Int
        switch elements[0] {
        case .int(let v) where Int(exactly: v) != nil: code = Int(v)
        case .uint(let v) where Int(exactly: v) != nil: code = Int(v)
        default: throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ParameterChangeAction type")
        }

        if case .null = elements[1] {
            id = nil
        } else {
            id = try GovActionID(from: elements[1])
        }

        // A parameter change is a Conway governance action, so its update
        // holds Conway's fields only.
        try LedgerFields.check(
            LedgerFields.keys(of: elements[2]), allowed: LedgerFields.protocolParamUpdate(.conway),
            era: .conway, in: "ProtocolParamUpdate")
        protocolParamUpdate = try ProtocolParamUpdate(from: elements[2])

        if case .null = elements[3] {
            policyHash = nil
        } else {
            policyHash = try PolicyHash(from: elements[3])
        }
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
            try protocolParamUpdate.toPrimitive(),
            policyHash?.toPrimitive() ?? .null,
        ])
    }
}

// MARK: - ProtocolParamUpdate

/// A protocol parameter update: `protocol_param_update`, a map from integer key to new value.
///
/// Each field is `nil` when the update leaves that parameter unchanged, and its doc names the CDDL key it is written under.
public struct ProtocolParamUpdate: CBORSerializable, Sendable {
    /// Key 0, `min_fee_a`: the fee per byte of transaction, in lovelace.
    public var minFeeA: Coin?
    /// Key 1, `min_fee_b`: the fixed part of the fee, in lovelace.
    public var minFeeB: Coin?
    /// Key 2: the maximum block body size, in bytes.
    public var maxBlockBodySize: UInt32?
    /// Key 3: the maximum transaction size, in bytes.
    public var maxTransactionSize: UInt32?
    /// Key 4: the maximum block header size, in bytes.
    public var maxBlockHeaderSize: UInt16?

    /// Key 5: the stake credential registration deposit, in lovelace.
    public var keyDeposit: Coin?
    /// Key 6: the stake pool registration deposit, in lovelace.
    public var poolDeposit: Coin?
    /// Key 7, `e_max`: how many epochs ahead a pool may schedule its retirement.
    public var maximumEpoch: EpochInterval?
    /// Key 8, `n_opt` (k): the target number of stake pools.
    public var nOpt: UInt16?
    /// Key 9, `a0`: the pool pledge influence.
    public var poolPledgeInfluence: NonNegativeInterval?

    /// Key 10, `rho`: the monetary expansion rate.
    public var expansionRate: UnitInterval?
    /// Key 11, `tau`: the treasury growth rate.
    public var treasuryGrowthRate: UnitInterval?
    /// Key 12, `d`: the decentralization parameter, Shelley to Alonzo.
    public var decentralizationConstant: UnitInterval?
    /// Key 13: extra entropy, `nonce = [0] / [1, bytes .size 32]`, Shelley to Alonzo.
    public var extraEntropy: Nonce?
    /// Key 14: the protocol version, Shelley to Babbage. Conway changes it with ``HardForkInitiationAction`` instead.
    public var protocolVersion: ProtocolVersion?
    /// Key 15, `min_utxo_value`: the minimum lovelace in an output, Shelley to Mary.
    public var minUtxoValue: Coin?

    /// Key 16: the minimum fixed cost of a stake pool, in lovelace.
    public var minPoolCost: Coin?
    /// Key 17: the cost of UTxO storage, in lovelace per byte (per word in Alonzo).
    public var adaPerUtxoByte: Coin?
    /// Key 18: the Plutus cost models.
    public var costModels: CostModels?
    /// Key 19: the prices of script execution memory and steps.
    public var executionCosts: ExUnitPrices?
    /// Key 20: the maximum execution units of one transaction.
    public var maxTxExUnits: ExUnits?
    /// Key 21: the maximum execution units of one block.
    public var maxBlockExUnits: ExUnits?
    /// Key 22: the maximum size of a serialized output value, in bytes.
    public var maxValueSize: UInt32?
    /// Key 23: the collateral required, as a percentage of the transaction fee.
    public var collateralPercentage: UInt16?

    /// Key 24: the maximum number of collateral inputs.
    public var maxCollateralInputs: UInt16?
    /// Key 25: the stake pool voting thresholds.
    public var poolVotingThresholds: PoolVotingThresholds?
    /// Key 26: the DRep voting thresholds.
    public var drepVotingThresholds: DrepVotingThresholds?
    /// Key 27: the minimum size of the constitutional committee.
    public var minCommitteeSize: UInt16?
    /// Key 28: the maximum term of a committee member, in epochs.
    public var committeeTermLimit: EpochInterval?

    /// Key 29: how long a governance action stays open for votes, in epochs.
    public var governanceActionValidityPeriod: EpochInterval?
    /// Key 30: the deposit for a governance proposal, in lovelace.
    public var governanceActionDeposit: Coin?
    /// Key 31: the DRep registration deposit, in lovelace.
    public var drepDeposit: Coin?
    /// Key 32: how many epochs a DRep can go without voting before it is inactive.
    public var drepInactivityPeriod: EpochInterval?
    /// Key 33: the fee per byte of reference scripts, in lovelace.
    public var minFeeRefScriptCoinsPerByte: NonNegativeInterval?

    enum CodingKeys: Int, CodingKey {
        case minFeeA = 0
        case minFeeB = 1
        case maxBlockBodySize = 2
        case maxTransactionSize = 3
        case maxBlockHeaderSize = 4

        case keyDeposit = 5
        case poolDeposit = 6
        case maximumEpoch = 7
        case nOpt = 8
        case poolPledgeInfluence = 9

        case expansionRate = 10
        case treasuryGrowthRate = 11
        case decentralizationConstant = 12
        case extraEntropy = 13
        case protocolVersion = 14
        case minUtxoValue = 15

        case minPoolCost = 16
        case adaPerUtxoByte = 17
        case costModels = 18
        case executionCosts = 19
        case maxTxExUnits = 20

        case maxBlockExUnits = 21
        case maxValueSize = 22
        case collateralPercentage = 23
        case maxCollateralInputs = 24
        case poolVotingThresholds = 25

        case drepVotingThresholds = 26
        case minCommitteeSize = 27
        case committeeTermLimit = 28
        case governanceActionValidityPeriod = 29
        case governanceActionDeposit = 30

        case drepDeposit = 31
        case drepInactivityPeriod = 32
        case minFeeRefScriptCoinsPerByte = 33
    }

    /// Creates a protocol parameter update. Leave a parameter `nil` to leave it unchanged.
    /// - Parameters:
    ///   - minFeeA: Key 0, the fee per byte, in lovelace.
    ///   - minFeeB: Key 1, the fixed fee, in lovelace.
    ///   - maxBlockBodySize: Key 2, in bytes.
    ///   - maxTransactionSize: Key 3, in bytes.
    ///   - maxBlockHeaderSize: Key 4, in bytes.
    ///   - keyDeposit: Key 5, in lovelace.
    ///   - poolDeposit: Key 6, in lovelace.
    ///   - maximumEpoch: Key 7, `e_max`.
    ///   - nOpt: Key 8, the target number of pools.
    ///   - poolPledgeInfluence: Key 9, `a0`.
    ///   - expansionRate: Key 10, `rho`.
    ///   - treasuryGrowthRate: Key 11, `tau`.
    ///   - decentralizationConstant: Key 12, `d`.
    ///   - extraEntropy: Key 13.
    ///   - protocolVersion: Key 14.
    ///   - minUtxoValue: Key 15, in lovelace.
    ///   - minPoolCost: Key 16, in lovelace.
    ///   - adaPerUtxoByte: Key 17, in lovelace.
    ///   - costModels: Key 18.
    ///   - executionCosts: Key 19.
    ///   - maxTxExUnits: Key 20.
    ///   - maxBlockExUnits: Key 21.
    ///   - maxValueSize: Key 22, in bytes.
    ///   - collateralPercentage: Key 23, a percentage of the fee.
    ///   - maxCollateralInputs: Key 24.
    ///   - poolVotingThresholds: Key 25.
    ///   - drepVotingThresholds: Key 26.
    ///   - minCommitteeSize: Key 27.
    ///   - committeeTermLimit: Key 28, in epochs.
    ///   - governanceActionValidityPeriod: Key 29, in epochs.
    ///   - governanceActionDeposit: Key 30, in lovelace.
    ///   - drepDeposit: Key 31, in lovelace.
    ///   - drepInactivityPeriod: Key 32, in epochs.
    ///   - minFeeRefScriptCoinsPerByte: Key 33, in lovelace per byte.
    public init(
        minFeeA: Coin? = nil,
        minFeeB: Coin? = nil,
        maxBlockBodySize: UInt32? = nil,
        maxTransactionSize: UInt32? = nil,
        maxBlockHeaderSize: UInt16? = nil,

        keyDeposit: Coin? = nil,
        poolDeposit: Coin? = nil,
        maximumEpoch: EpochInterval? = nil,
        nOpt: UInt16? = nil,
        poolPledgeInfluence: NonNegativeInterval? = nil,

        expansionRate: UnitInterval? = nil,
        treasuryGrowthRate: UnitInterval? = nil,
        decentralizationConstant: UnitInterval? = nil,
        extraEntropy: Nonce? = nil,
        protocolVersion: ProtocolVersion? = nil,
        minUtxoValue: Coin? = nil,

        minPoolCost: Coin? = nil,
        adaPerUtxoByte: Coin? = nil,
        costModels: CostModels? = nil,
        executionCosts: ExUnitPrices? = nil,
        maxTxExUnits: ExUnits? = nil,
        maxBlockExUnits: ExUnits? = nil,
        maxValueSize: UInt32? = nil,
        collateralPercentage: UInt16? = nil,

        maxCollateralInputs: UInt16? = nil,
        poolVotingThresholds: PoolVotingThresholds? = nil,
        drepVotingThresholds: DrepVotingThresholds? = nil,
        minCommitteeSize: UInt16? = nil,
        committeeTermLimit: EpochInterval? = nil,

        governanceActionValidityPeriod: EpochInterval? = nil,
        governanceActionDeposit: Coin? = nil,
        drepDeposit: Coin? = nil,
        drepInactivityPeriod: EpochInterval? = nil,
        minFeeRefScriptCoinsPerByte: NonNegativeInterval? = nil
    ) {
        self.minFeeA = minFeeA
        self.minFeeB = minFeeB
        self.maxBlockBodySize = maxBlockBodySize
        self.maxTransactionSize = maxTransactionSize
        self.maxBlockHeaderSize = maxBlockHeaderSize

        self.keyDeposit = keyDeposit
        self.poolDeposit = poolDeposit
        self.maximumEpoch = maximumEpoch
        self.nOpt = nOpt
        self.poolPledgeInfluence = poolPledgeInfluence

        self.expansionRate = expansionRate
        self.treasuryGrowthRate = treasuryGrowthRate
        self.decentralizationConstant = decentralizationConstant
        self.extraEntropy = extraEntropy
        self.protocolVersion = protocolVersion
        self.minUtxoValue = minUtxoValue

        self.minPoolCost = minPoolCost
        self.adaPerUtxoByte = adaPerUtxoByte
        self.costModels = costModels
        self.executionCosts = executionCosts
        self.maxTxExUnits = maxTxExUnits
        self.maxBlockExUnits = maxBlockExUnits
        self.maxValueSize = maxValueSize
        self.collateralPercentage = collateralPercentage

        self.maxCollateralInputs = maxCollateralInputs
        self.poolVotingThresholds = poolVotingThresholds
        self.drepVotingThresholds = drepVotingThresholds
        self.minCommitteeSize = minCommitteeSize
        self.committeeTermLimit = committeeTermLimit

        self.governanceActionValidityPeriod = governanceActionValidityPeriod
        self.governanceActionDeposit = governanceActionDeposit
        self.drepDeposit = drepDeposit
        self.drepInactivityPeriod = drepInactivityPeriod
        self.minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte
    }

    /// CBOR goes through `init(from: Primitive)`, the integer-keyed map
    /// the CDDL defines. JSON is an object keyed by the field names.
    public init(from decoder: Decoder) throws {
        guard String(describing: type(of: decoder)).contains("JSONDecoder") else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        minFeeA = try container.decodeIfPresent(Coin.self, forKey: .minFeeA)
        minFeeB = try container.decodeIfPresent(Coin.self, forKey: .minFeeB)
        maxBlockBodySize = try container.decodeIfPresent(UInt32.self, forKey: .maxBlockBodySize)
        maxTransactionSize = try container.decodeIfPresent(UInt32.self, forKey: .maxTransactionSize)
        maxBlockHeaderSize = try container.decodeIfPresent(UInt16.self, forKey: .maxBlockHeaderSize)

        keyDeposit = try container.decodeIfPresent(Coin.self, forKey: .keyDeposit)
        poolDeposit = try container.decodeIfPresent(Coin.self, forKey: .poolDeposit)
        maximumEpoch = try container.decodeIfPresent(EpochInterval.self, forKey: .maximumEpoch)
        nOpt = try container.decodeIfPresent(UInt16.self, forKey: .nOpt)
        poolPledgeInfluence = try container.decodeIfPresent(
            NonNegativeInterval.self, forKey: .poolPledgeInfluence)

        expansionRate = try container.decodeIfPresent(UnitInterval.self, forKey: .expansionRate)
        treasuryGrowthRate = try container.decodeIfPresent(
            UnitInterval.self, forKey: .treasuryGrowthRate)
        decentralizationConstant = try container.decodeIfPresent(
            UnitInterval.self, forKey: .decentralizationConstant)
        extraEntropy = try container.decodeIfPresent(Nonce.self, forKey: .extraEntropy)
        protocolVersion = try container.decodeIfPresent(
            ProtocolVersion.self, forKey: .protocolVersion)
        minUtxoValue = try container.decodeIfPresent(Coin.self, forKey: .minUtxoValue)

        minPoolCost = try container.decodeIfPresent(Coin.self, forKey: .minPoolCost)
        adaPerUtxoByte = try container.decodeIfPresent(Coin.self, forKey: .adaPerUtxoByte)
        costModels = try container.decodeIfPresent(CostModels.self, forKey: .costModels)
        executionCosts = try container.decodeIfPresent(ExUnitPrices.self, forKey: .executionCosts)
        maxTxExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxTxExUnits)
        maxBlockExUnits = try container.decodeIfPresent(ExUnits.self, forKey: .maxBlockExUnits)
        maxValueSize = try container.decodeIfPresent(UInt32.self, forKey: .maxValueSize)
        collateralPercentage = try container.decodeIfPresent(
            UInt16.self, forKey: .collateralPercentage)

        maxCollateralInputs = try container.decodeIfPresent(
            UInt16.self, forKey: .maxCollateralInputs)
        poolVotingThresholds = try container.decodeIfPresent(
            PoolVotingThresholds.self, forKey: .poolVotingThresholds)
        drepVotingThresholds = try container.decodeIfPresent(
            DrepVotingThresholds.self, forKey: .drepVotingThresholds)
        minCommitteeSize = try container.decodeIfPresent(UInt16.self, forKey: .minCommitteeSize)
        committeeTermLimit = try container.decodeIfPresent(
            EpochInterval.self, forKey: .committeeTermLimit)

        governanceActionValidityPeriod = try container.decodeIfPresent(
            EpochInterval.self, forKey: .governanceActionValidityPeriod)
        governanceActionDeposit = try container.decodeIfPresent(
            Coin.self, forKey: .governanceActionDeposit)
        drepDeposit = try container.decodeIfPresent(Coin.self, forKey: .drepDeposit)
        drepInactivityPeriod = try container.decodeIfPresent(
            EpochInterval.self, forKey: .drepInactivityPeriod)
        minFeeRefScriptCoinsPerByte = try container.decodeIfPresent(
            NonNegativeInterval.self, forKey: .minFeeRefScriptCoinsPerByte)
    }

    public func encode(to encoder: Encoder) throws {
        guard String(describing: type(of: encoder)).contains("JSONEncoder") else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(minFeeA, forKey: .minFeeA)
        try container.encodeIfPresent(minFeeB, forKey: .minFeeB)
        try container.encodeIfPresent(maxBlockBodySize, forKey: .maxBlockBodySize)
        try container.encodeIfPresent(maxTransactionSize, forKey: .maxTransactionSize)
        try container.encodeIfPresent(maxBlockHeaderSize, forKey: .maxBlockHeaderSize)

        try container.encodeIfPresent(keyDeposit, forKey: .keyDeposit)
        try container.encodeIfPresent(poolDeposit, forKey: .poolDeposit)
        try container.encodeIfPresent(maximumEpoch, forKey: .maximumEpoch)
        try container.encodeIfPresent(nOpt, forKey: .nOpt)
        try container.encodeIfPresent(poolPledgeInfluence, forKey: .poolPledgeInfluence)

        try container.encodeIfPresent(expansionRate, forKey: .expansionRate)
        try container.encodeIfPresent(treasuryGrowthRate, forKey: .treasuryGrowthRate)
        try container.encodeIfPresent(decentralizationConstant, forKey: .decentralizationConstant)
        try container.encodeIfPresent(extraEntropy, forKey: .extraEntropy)
        try container.encodeIfPresent(protocolVersion, forKey: .protocolVersion)
        try container.encodeIfPresent(minUtxoValue, forKey: .minUtxoValue)

        try container.encodeIfPresent(minPoolCost, forKey: .minPoolCost)
        try container.encodeIfPresent(adaPerUtxoByte, forKey: .adaPerUtxoByte)
        try container.encodeIfPresent(costModels, forKey: .costModels)
        try container.encodeIfPresent(executionCosts, forKey: .executionCosts)
        try container.encodeIfPresent(maxTxExUnits, forKey: .maxTxExUnits)
        try container.encodeIfPresent(maxBlockExUnits, forKey: .maxBlockExUnits)
        try container.encodeIfPresent(maxValueSize, forKey: .maxValueSize)
        try container.encodeIfPresent(collateralPercentage, forKey: .collateralPercentage)

        try container.encodeIfPresent(maxCollateralInputs, forKey: .maxCollateralInputs)
        try container.encodeIfPresent(poolVotingThresholds, forKey: .poolVotingThresholds)
        try container.encodeIfPresent(drepVotingThresholds, forKey: .drepVotingThresholds)
        try container.encodeIfPresent(minCommitteeSize, forKey: .minCommitteeSize)
        try container.encodeIfPresent(committeeTermLimit, forKey: .committeeTermLimit)

        try container.encodeIfPresent(
            governanceActionValidityPeriod, forKey: .governanceActionValidityPeriod)
        try container.encodeIfPresent(governanceActionDeposit, forKey: .governanceActionDeposit)
        try container.encodeIfPresent(drepDeposit, forKey: .drepDeposit)
        try container.encodeIfPresent(drepInactivityPeriod, forKey: .drepInactivityPeriod)
        try container.encodeIfPresent(
            minFeeRefScriptCoinsPerByte, forKey: .minFeeRefScriptCoinsPerByte)
    }

    public init(from primitive: Primitive) throws {
        var pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d):
            pairs = Array(d)
        case .orderedDict(let od), .indefiniteDictionary(let od):
            pairs = od.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate type")
        }

        // A sparse record, as the ledger reads it: every key has to be a
        // parameter's, and none may appear twice.
        var dict = [Int: Primitive]()
        for (key, value) in pairs {
            let index: Int
            switch key {
            case .int(let keyValue) where Int(exactly: keyValue) != nil:
                index = Int(keyValue)
            case .uint(let keyValue) where Int(exactly: keyValue) != nil:
                index = Int(keyValue)
            default:
                throw CardanoCoreError.deserializeError("Invalid ProtocolParamUpdate key: \(key)")
            }
            guard CodingKeys(rawValue: index) != nil else {
                throw CardanoCoreError.deserializeError("ProtocolParamUpdate: unknown key \(index)")
            }
            guard dict.updateValue(value, forKey: index) == nil else {
                throw CardanoCoreError.deserializeError("ProtocolParamUpdate: key \(index) appears more than once")
            }
        }

        /// The unsigned integer under `key`, or `nil` when there is none. A
        /// value outside the field's range fails to decode, as in the ledger.
        func number<T: FixedWidthInteger & UnsignedInteger>(_ key: CodingKeys) throws -> T? {
            guard let primitive = dict[key.rawValue] else { return nil }
            let value: T?
            switch primitive {
            case .uint(let v): value = T(exactly: v)
            case .int(let v): value = T(exactly: v)
            default: value = nil
            }
            guard let value else {
                throw CardanoCoreError.deserializeError(
                    "Protocol parameter \(key) out of range for \(T.self): \(primitive)")
            }
            return value
        }

        minFeeA = try number(.minFeeA)
        minFeeB = try number(.minFeeB)

        maxBlockBodySize = try number(.maxBlockBodySize)

        maxTransactionSize = try number(.maxTransactionSize)

        maxBlockHeaderSize = try number(.maxBlockHeaderSize)

        keyDeposit = try number(.keyDeposit)
        poolDeposit = try number(.poolDeposit)

        maximumEpoch = try number(.maximumEpoch)

        nOpt = try number(.nOpt)

        if let poolPledgeInfluencePrimitive = dict[CodingKeys.poolPledgeInfluence.rawValue] {
            poolPledgeInfluence = try NonNegativeInterval(from: poolPledgeInfluencePrimitive)
        } else {
            poolPledgeInfluence = nil
        }

        if let expansionRatePrimitive = dict[CodingKeys.expansionRate.rawValue] {
            expansionRate = try UnitInterval(from: expansionRatePrimitive)
        } else {
            expansionRate = nil
        }

        if let treasuryGrowthRatePrimitive = dict[CodingKeys.treasuryGrowthRate.rawValue] {
            treasuryGrowthRate = try UnitInterval(from: treasuryGrowthRatePrimitive)
        } else {
            treasuryGrowthRate = nil
        }

        if let decentralizationConstantPrimitive = dict[
            CodingKeys.decentralizationConstant.rawValue]
        {
            decentralizationConstant = try UnitInterval(from: decentralizationConstantPrimitive)
        } else {
            decentralizationConstant = nil
        }

        if let extraEntropyPrimitive = dict[CodingKeys.extraEntropy.rawValue] {
            extraEntropy = try Nonce(from: extraEntropyPrimitive)
        } else {
            extraEntropy = nil
        }

        if let protocolVersionPrimitive = dict[CodingKeys.protocolVersion.rawValue] {
            protocolVersion = try ProtocolVersion(from: protocolVersionPrimitive)
        } else {
            protocolVersion = nil
        }

        minUtxoValue = try number(.minUtxoValue)

        minPoolCost = try number(.minPoolCost)
        adaPerUtxoByte = try number(.adaPerUtxoByte)

        if let costModelsPrimitive = dict[CodingKeys.costModels.rawValue] {
            costModels = try CostModels(from: costModelsPrimitive)
        } else {
            costModels = nil
        }

        if let executionCostsPrimitive = dict[CodingKeys.executionCosts.rawValue] {
            executionCosts = try ExUnitPrices(from: executionCostsPrimitive)
        } else {
            executionCosts = nil
        }

        if let maxTxExUnitsPrimitive = dict[CodingKeys.maxTxExUnits.rawValue] {
            maxTxExUnits = try ExUnits(from: maxTxExUnitsPrimitive)
        } else {
            maxTxExUnits = nil
        }

        if let maxBlockExUnitsPrimitive = dict[CodingKeys.maxBlockExUnits.rawValue] {
            maxBlockExUnits = try ExUnits(from: maxBlockExUnitsPrimitive)
        } else {
            maxBlockExUnits = nil
        }

        maxValueSize = try number(.maxValueSize)
        collateralPercentage = try number(.collateralPercentage)
        maxCollateralInputs = try number(.maxCollateralInputs)

        if let poolVotingThresholdsPrimitive = dict[CodingKeys.poolVotingThresholds.rawValue] {
            poolVotingThresholds = try PoolVotingThresholds(from: poolVotingThresholdsPrimitive)
        } else {
            poolVotingThresholds = nil
        }

        if let drepVotingThresholdsPrimitive = dict[CodingKeys.drepVotingThresholds.rawValue] {
            drepVotingThresholds = try DrepVotingThresholds(from: drepVotingThresholdsPrimitive)
        } else {
            drepVotingThresholds = nil
        }

        minCommitteeSize = try number(.minCommitteeSize)
        committeeTermLimit = try number(.committeeTermLimit)
        governanceActionValidityPeriod = try number(.governanceActionValidityPeriod)

        governanceActionDeposit = try number(.governanceActionDeposit)
        drepDeposit = try number(.drepDeposit)

        drepInactivityPeriod = try number(.drepInactivityPeriod)

        if let minFeeRefScriptCoinsPerBytePrimitive = dict[
            CodingKeys.minFeeRefScriptCoinsPerByte.rawValue]
        {
            minFeeRefScriptCoinsPerByte = try NonNegativeInterval(
                from: minFeeRefScriptCoinsPerBytePrimitive)
        } else {
            minFeeRefScriptCoinsPerByte = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        if let minFeeA = minFeeA {
            dict[.uint(UInt64(CodingKeys.minFeeA.rawValue))] = .uint(UInt64(minFeeA))
        }
        if let minFeeB = minFeeB {
            dict[.uint(UInt64(CodingKeys.minFeeB.rawValue))] = .uint(UInt64(minFeeB))
        }
        if let maxBlockBodySize = maxBlockBodySize {
            dict[.uint(UInt64(CodingKeys.maxBlockBodySize.rawValue))] = .uint(UInt64(maxBlockBodySize))
        }
        if let maxTransactionSize = maxTransactionSize {
            dict[.uint(UInt64(CodingKeys.maxTransactionSize.rawValue))] = .uint(UInt64(maxTransactionSize))
        }
        if let maxBlockHeaderSize = maxBlockHeaderSize {
            dict[.uint(UInt64(CodingKeys.maxBlockHeaderSize.rawValue))] = .uint(UInt64(maxBlockHeaderSize))
        }

        if let keyDeposit = keyDeposit {
            dict[.uint(UInt64(CodingKeys.keyDeposit.rawValue))] = .uint(UInt64(keyDeposit))
        }
        if let poolDeposit = poolDeposit {
            dict[.uint(UInt64(CodingKeys.poolDeposit.rawValue))] = .uint(UInt64(poolDeposit))
        }
        if let maximumEpoch = maximumEpoch {
            dict[.uint(UInt64(CodingKeys.maximumEpoch.rawValue))] = .uint(UInt64(maximumEpoch))
        }
        if let nOpt = nOpt {
            dict[.uint(UInt64(CodingKeys.nOpt.rawValue))] = .uint(UInt64(nOpt))
        }
        if let poolPledgeInfluence = poolPledgeInfluence {
            dict[.uint(UInt64(CodingKeys.poolPledgeInfluence.rawValue))] =
                try poolPledgeInfluence.toPrimitive()
        }

        if let expansionRate = expansionRate {
            dict[.uint(UInt64(CodingKeys.expansionRate.rawValue))] = try expansionRate.toPrimitive()
        }
        if let treasuryGrowthRate = treasuryGrowthRate {
            dict[.uint(UInt64(CodingKeys.treasuryGrowthRate.rawValue))] =
                try treasuryGrowthRate.toPrimitive()
        }
        if let decentralizationConstant = decentralizationConstant {
            dict[.uint(UInt64(CodingKeys.decentralizationConstant.rawValue))] =
                try decentralizationConstant.toPrimitive()
        }
        if let extraEntropy = extraEntropy {
            dict[.uint(UInt64(CodingKeys.extraEntropy.rawValue))] = try extraEntropy.toPrimitive()
        }
        if let protocolVersion = protocolVersion {
            dict[.uint(UInt64(CodingKeys.protocolVersion.rawValue))] = try protocolVersion.toPrimitive()
        }
        if let minUtxoValue = minUtxoValue {
            dict[.uint(UInt64(CodingKeys.minUtxoValue.rawValue))] = .uint(UInt64(minUtxoValue))
        }

        if let minPoolCost = minPoolCost {
            dict[.uint(UInt64(CodingKeys.minPoolCost.rawValue))] = .uint(UInt64(minPoolCost))
        }
        if let adaPerUtxoByte = adaPerUtxoByte {
            dict[.uint(UInt64(CodingKeys.adaPerUtxoByte.rawValue))] = .uint(UInt64(adaPerUtxoByte))
        }
        if let costModels = costModels {
            dict[.uint(UInt64(CodingKeys.costModels.rawValue))] = try costModels.toPrimitive()
        }
        if let executionCosts = executionCosts {
            dict[.uint(UInt64(CodingKeys.executionCosts.rawValue))] = try executionCosts.toPrimitive()
        }
        if let maxTxExUnits = maxTxExUnits {
            dict[.uint(UInt64(CodingKeys.maxTxExUnits.rawValue))] = try maxTxExUnits.toPrimitive()
        }
        if let maxBlockExUnits = maxBlockExUnits {
            dict[.uint(UInt64(CodingKeys.maxBlockExUnits.rawValue))] = try maxBlockExUnits.toPrimitive()
        }
        if let maxValueSize = maxValueSize {
            dict[.uint(UInt64(CodingKeys.maxValueSize.rawValue))] = .uint(UInt64(maxValueSize))
        }
        if let collateralPercentage = collateralPercentage {
            dict[.uint(UInt64(CodingKeys.collateralPercentage.rawValue))] = .uint(UInt64(collateralPercentage))
        }

        if let maxCollateralInputs = maxCollateralInputs {
            dict[.uint(UInt64(CodingKeys.maxCollateralInputs.rawValue))] = .uint(UInt64(maxCollateralInputs))
        }
        if let poolVotingThresholds = poolVotingThresholds {
            dict[.uint(UInt64(CodingKeys.poolVotingThresholds.rawValue))] =
                try poolVotingThresholds.toPrimitive()
        }
        if let drepVotingThresholds = drepVotingThresholds {
            dict[.uint(UInt64(CodingKeys.drepVotingThresholds.rawValue))] =
                try drepVotingThresholds.toPrimitive()
        }
        if let minCommitteeSize = minCommitteeSize {
            dict[.uint(UInt64(CodingKeys.minCommitteeSize.rawValue))] = .uint(UInt64(minCommitteeSize))
        }
        if let committeeTermLimit = committeeTermLimit {
            dict[.uint(UInt64(CodingKeys.committeeTermLimit.rawValue))] = .uint(UInt64(committeeTermLimit))
        }

        if let governanceActionValidityPeriod = governanceActionValidityPeriod {
            dict[.uint(UInt64(CodingKeys.governanceActionValidityPeriod.rawValue))] = .integer(governanceActionValidityPeriod)
        }
        if let governanceActionDeposit = governanceActionDeposit {
            dict[.uint(UInt64(CodingKeys.governanceActionDeposit.rawValue))] = .integer(governanceActionDeposit)
        }
        if let drepDeposit = drepDeposit {
            dict[.uint(UInt64(CodingKeys.drepDeposit.rawValue))] = .uint(UInt64(drepDeposit))
        }
        if let drepInactivityPeriod = drepInactivityPeriod {
            dict[.uint(UInt64(CodingKeys.drepInactivityPeriod.rawValue))] = .uint(UInt64(drepInactivityPeriod))
        }
        if let minFeeRefScriptCoinsPerByte = minFeeRefScriptCoinsPerByte {
            dict[.uint(UInt64(CodingKeys.minFeeRefScriptCoinsPerByte.rawValue))] =
                try minFeeRefScriptCoinsPerByte.toPrimitive()
        }

        // In ascending field order, so an update always encodes the same way.
        dict.sort { lhs, rhs in
            guard case .uint(let l) = lhs.key, case .uint(let r) = rhs.key else { return false }
            return l < r
        }
        return .orderedDict(dict)
    }
}

// MARK: - ProtocolParamUpdate + ProtocolParameters conversion

extension ProtocolParamUpdate {
    /// Builds a `ProtocolParamUpdate` from the current network `ProtocolParameters`.
    ///
    /// Useful as a starting point for a `ParameterChangeAction`: populate all
    /// fields from the current params and then nil-out the fields you do NOT
    /// want to change. Rates are copied exactly, reduced as the ledger holds
    /// them; fields that have no clean on-chain representation are set to
    /// `nil` and must be supplied manually if needed.
    public init(from p: ProtocolParameters) {
        func unit(_ value: UnitInterval) -> UnitInterval {
            let (n, d) = LedgerRational.reduced(value.numerator, value.denominator)
            return UnitInterval(numerator: n, denominator: d)
        }
        func nonNegative(_ value: NonNegativeInterval) -> NonNegativeInterval {
            let (n, d) = LedgerRational.reduced(value.numerator, value.denominator)
            return NonNegativeInterval(numerator: n, denominator: d)
        }
        minFeeA = p.txFeePerByte
        minFeeB = p.txFeeFixed
        maxBlockBodySize = p.maxBlockBodySize
        maxTransactionSize = p.maxTxSize
        maxBlockHeaderSize = p.maxBlockHeaderSize
        keyDeposit = p.stakeAddressDeposit
        poolDeposit = p.stakePoolDeposit
        maximumEpoch = p.poolRetireMaxEpoch
        nOpt = p.stakePoolTargetNum
        poolPledgeInfluence = nonNegative(p.poolPledgeInfluence)
        expansionRate = unit(p.monetaryExpansion)
        treasuryGrowthRate = unit(p.treasuryCut)
        decentralizationConstant = nil
        extraEntropy = nil
        minUtxoValue = nil
        // A parameter change cannot carry the protocol version (key 14 is
        // gone from Conway's protocol_param_update): it moves by a hard-fork
        // initiation action.
        protocolVersion = nil
        minPoolCost = p.minPoolCost
        adaPerUtxoByte = p.utxoCostPerByte

        costModels = try? CostModels([
            0: p.costModels.PlutusV1,
            1: p.costModels.PlutusV2,
            2: p.costModels.PlutusV3,
        ])

        executionCosts = ExUnitPrices(
            memPrice: nonNegative(p.executionUnitPrices.priceMemory),
            stepPrice: nonNegative(p.executionUnitPrices.priceSteps))

        maxTxExUnits = ExUnits(
            mem: p.maxTxExecutionUnits.memory, steps: p.maxTxExecutionUnits.steps)
        maxBlockExUnits = ExUnits(
            mem: p.maxBlockExecutionUnits.memory, steps: p.maxBlockExecutionUnits.steps)
        maxValueSize = p.maxValueSize
        collateralPercentage = p.collateralPercentage
        maxCollateralInputs = p.maxCollateralInputs

        let pool = p.poolVotingThresholds.ledgerOrder.map(unit)
        poolVotingThresholds = PoolVotingThresholds(
            motionNoConfidence: pool[0],
            committeeNormal: pool[1],
            committeeNoConfidence: pool[2],
            hardForkInitiation: pool[3],
            ppSecurityGroup: pool[4])
        // ledgerOrder always holds the ten DRep thresholds.
        drepVotingThresholds = DrepVotingThresholds(ledgerOrder: p.dRepVotingThresholds.ledgerOrder.map(unit))

        minCommitteeSize = p.committeeMinSize
        committeeTermLimit = p.committeeMaxTermLength
        governanceActionValidityPeriod = p.govActionLifetime
        governanceActionDeposit = p.govActionDeposit
        drepDeposit = p.dRepDeposit
        drepInactivityPeriod = p.dRepActivity
        minFeeRefScriptCoinsPerByte = p.minFeeRefScriptCostPerByte.map(nonNegative)
    }
}
