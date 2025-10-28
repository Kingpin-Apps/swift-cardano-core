import Foundation
import SwiftNcal
import PotentCBOR
import OrderedCollections

public struct TransactionBody: Serializable {
    public var inputs: ListOrOrderedSet<TransactionInput>
    public var outputs: [TransactionOutput]
    public var fee: Coin
    public var ttl: Int?
    public var certificates: ListOrNonEmptyOrderedSet<Certificate>?
    public var withdrawals: Withdrawals?
    public var update: Update?
    public var auxiliaryDataHash: AuxiliaryDataHash?
    public var validityStart: Int?
    public var mint: MultiAsset?
    public var scriptDataHash: ScriptDataHash?
    public var collateral: ListOrNonEmptyOrderedSet<TransactionInput>?
    public var requiredSigners: ListOrNonEmptyOrderedSet<VerificationKeyHash>?
    public var networkId: Int?
    public var collateralReturn: TransactionOutput?
    public var totalCollateral: Coin?
    public var referenceInputs: ListOrNonEmptyOrderedSet<TransactionInput>?
    public var votingProcedures: VotingProcedures?
    public var proposalProcedures: ProposalProcedures?
    public var currentTreasuryAmount: Coin?
    public var treasuryDonation: PositiveCoin?
    
    enum CodingKeys: Int, CodingKey {
        case inputs = 0
        case outputs = 1
        case fee = 2
        case ttl = 3
        case certificates = 4
        case withdrawals = 5
        case update = 6
        case auxiliaryDataHash = 7
        case validityStart = 8
        case mint = 9
        case scriptDataHash = 11
        case collateral = 13
        case requiredSigners = 14
        case networkId = 15
        case collateralReturn = 16
        case totalCollateral = 17
        case referenceInputs = 18
        case votingProcedures = 19
        case proposalProcedures = 20
        case currentTreasuryAmount = 21
        case treasuryDonation = 22
        
        var stringValue: String {
            switch self {
            case .inputs: return "inputs"
            case .outputs: return "outputs"
            case .fee: return "fee"
            case .ttl: return "ttl"
            case .certificates: return "certificates"
            case .withdrawals: return "withdrawals"
            case .update: return "update"
            case .auxiliaryDataHash: return "auxiliaryDataHash"
            case .validityStart: return "validityStart"
            case .mint: return "mint"
            case .scriptDataHash: return "scriptDataHash"
            case .collateral: return "collateral"
            case .requiredSigners: return "requiredSigners"
            case .networkId: return "networkId"
            case .collateralReturn: return "collateralReturn"
            case .totalCollateral: return "totalCollateral"
            case .referenceInputs: return "referenceInputs"
            case .votingProcedures: return "votingProcedures"
            case .proposalProcedures: return "proposalProcedures"
            case .currentTreasuryAmount: return "currentTreasuryAmount"
            case .treasuryDonation: return "treasuryDonation"
            }
        }
    }
    
    public init(
        inputs: ListOrOrderedSet<TransactionInput>,
        outputs: [TransactionOutput],
        fee: Coin,
        ttl: Int? = nil,
        certificates: ListOrNonEmptyOrderedSet<Certificate>? = nil,
        withdrawals: Withdrawals? = nil,
        update: Update? = nil,
        auxiliaryDataHash: AuxiliaryDataHash? = nil,
        validityStart: Int? = nil,
        mint: MultiAsset? = nil,
        scriptDataHash: ScriptDataHash? = nil,
        collateral: ListOrNonEmptyOrderedSet<TransactionInput>? = nil,
        requiredSigners: ListOrNonEmptyOrderedSet<VerificationKeyHash>? = nil,
        networkId: Int? = nil,
        collateralReturn: TransactionOutput? = nil,
        totalCollateral: Coin? = nil,
        referenceInputs: ListOrNonEmptyOrderedSet<TransactionInput>? = nil,
        votingProcedures: VotingProcedures? = nil,
        proposalProcedures: ProposalProcedures? = nil,
        currentTreasuryAmount: Coin? = nil,
        treasuryDonation: PositiveCoin? = nil
    ) {
        self.inputs = inputs
        self.outputs = outputs
        self.fee = fee
        self.ttl = ttl
        self.certificates = certificates
        self.withdrawals = withdrawals
        self.update = update
        self.auxiliaryDataHash = auxiliaryDataHash
        self.validityStart = validityStart
        self.mint = mint
        self.scriptDataHash = scriptDataHash
        self.collateral = collateral
        self.requiredSigners = requiredSigners
        self.networkId = networkId
        self.collateralReturn = collateralReturn
        self.totalCollateral = totalCollateral
        self.referenceInputs = referenceInputs
        self.votingProcedures = votingProcedures
        self.proposalProcedures = proposalProcedures
        self.currentTreasuryAmount = currentTreasuryAmount
        self.treasuryDonation = treasuryDonation
    }

    public func validate() throws {
        // Check mint asset bounds - values should be within reasonable bounds for Cardano
        // Cardano uses 64-bit signed integers, but very large values can cause issues
        let maxMintAmount = 45_000_000_000_000_000 // Maximum reasonable mint amount for Cardano
        if let mint = mint, try mint
            .count(criteria: { _, _, v in abs(v) > maxMintAmount }) > 0 {
            throw CardanoCoreError.invalidArgument("Invalid mint amount: \(mint)")
        }
        
        // Validate all outputs
        for output in outputs {
            try output.validate()
        }
    }

    public var id: TransactionId {
        return TransactionId(payload: hash())
    }
    
    public func hash() -> Data {
        return try! Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: TRANSACTION_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        var primitiveDict: OrderedDictionary<Primitive, Primitive> = [:]
        
        switch primitive {
            case let .dict(dict):
                primitiveDict.merge(dict) { (_, new) in new }
            case let .orderedDict(orderedDict):
                primitiveDict = orderedDict
            default:
                throw CardanoCoreError.deserializeError("Invalid TransactionBody type: \(primitive)")
        }
        
        func key(_ key: CodingKeys) -> Primitive {
            return .uint(UInt(key.rawValue))
        }
        
        // Required fields
        guard let inputsPrimitive = primitiveDict[key(CodingKeys.inputs)] else {
            throw CardanoCoreError.deserializeError("TransactionBody inputs are required")
        }
        inputs = try ListOrOrderedSet<TransactionInput>(from: inputsPrimitive)
        
        guard let outputsPrimitive = primitiveDict[key(CodingKeys.outputs)] else {
            throw CardanoCoreError.deserializeError("TransactionBody outputs are required")
        }
        if case let .list(outputsList) = outputsPrimitive {
            outputs = try outputsList.map { try TransactionOutput(from: $0) }
        } else {
            throw CardanoCoreError.deserializeError("TransactionBody outputs must be an array")
        }
        
        guard let feePrimitive = primitiveDict[key(CodingKeys.fee)] else {
            throw CardanoCoreError.deserializeError("TransactionBody fee is required")
        }
        if case let .uint(feeValue) = feePrimitive {
            fee = Coin(feeValue)
        } else {
            throw CardanoCoreError.deserializeError("TransactionBody fee must be an integer")
        }
        
        // Optional fields
        if let ttlPrimitive = primitiveDict[key(CodingKeys.ttl)],
           case let .uint(ttlValue) = ttlPrimitive {
            ttl = Int(ttlValue)
        } else {
            ttl = nil
        }
        
        if let certificatesPrimitive = primitiveDict[key(CodingKeys.certificates)] {
            certificates = try ListOrNonEmptyOrderedSet<Certificate>(from: certificatesPrimitive)
        } else {
            certificates = nil
        }
        
        if let withdrawalsPrimitive = primitiveDict[key(CodingKeys.withdrawals)] {
            withdrawals = try Withdrawals(from: withdrawalsPrimitive)
        } else {
            withdrawals = nil
        }
        
        if let updatePrimitive = primitiveDict[key(CodingKeys.update)] {
            update = try Update(from: updatePrimitive)
        } else {
            update = nil
        }
        
        if let auxiliaryDataHashPrimitive = primitiveDict[key(CodingKeys.auxiliaryDataHash)] {
            auxiliaryDataHash = try AuxiliaryDataHash(from: auxiliaryDataHashPrimitive)
        } else {
            auxiliaryDataHash = nil
        }
        
        if let validityStartPrimitive = primitiveDict[key(CodingKeys.validityStart)],
           case let .uint(validityStartValue) = validityStartPrimitive {
            validityStart = Int(validityStartValue)
        } else {
            validityStart = nil
        }
        
        if let mintPrimitive = primitiveDict[key(CodingKeys.mint)] {
            mint = try MultiAsset(from: mintPrimitive)
        } else {
            mint = nil
        }
        
        if let scriptDataHashPrimitive = primitiveDict[key(CodingKeys.scriptDataHash)] {
            scriptDataHash = try ScriptDataHash(from: scriptDataHashPrimitive)
        } else {
            scriptDataHash = nil
        }
        
        if let collateralPrimitive = primitiveDict[key(CodingKeys.collateral)] {
            collateral = try ListOrNonEmptyOrderedSet<TransactionInput>(from: collateralPrimitive)
        } else {
            collateral = nil
        }
        
        if let requiredSignersPrimitive = primitiveDict[key(CodingKeys.requiredSigners)] {
            requiredSigners = try ListOrNonEmptyOrderedSet<VerificationKeyHash>(from: requiredSignersPrimitive)
        } else {
            requiredSigners = nil
        }
        
        if let networkIdPrimitive = primitiveDict[key(CodingKeys.networkId)],
           case let .uint(networkIdValue) = networkIdPrimitive {
            networkId = Int(networkIdValue)
        } else {
            networkId = nil
        }
        
        if let collateralReturnPrimitive = primitiveDict[key(CodingKeys.collateralReturn)] {
            collateralReturn = try TransactionOutput(from: collateralReturnPrimitive)
        } else {
            collateralReturn = nil
        }
        
        if let totalCollateralPrimitive = primitiveDict[key(CodingKeys.totalCollateral)],
           case let .uint(totalCollateralValue) = totalCollateralPrimitive {
            totalCollateral = Coin(totalCollateralValue)
        } else {
            totalCollateral = nil
        }
        
        if let referenceInputsPrimitive = primitiveDict[key(CodingKeys.referenceInputs)] {
            referenceInputs = try ListOrNonEmptyOrderedSet<TransactionInput>(from: referenceInputsPrimitive)
        } else {
            referenceInputs = nil
        }
        
        if let votingProceduresPrimitive = primitiveDict[key(CodingKeys.votingProcedures)] {
            votingProcedures = try VotingProcedures(from: votingProceduresPrimitive)
        } else {
            votingProcedures = nil
        }
        
        if let proposalProceduresPrimitive = primitiveDict[key(CodingKeys.proposalProcedures)] {
            proposalProcedures = try ProposalProcedures(from: proposalProceduresPrimitive)
        } else {
            proposalProcedures = nil
        }
        
        if let currentTreasuryAmountPrimitive = primitiveDict[key(CodingKeys.currentTreasuryAmount)],
           case let .uint(currentTreasuryAmountValue) = currentTreasuryAmountPrimitive {
            currentTreasuryAmount = Coin(currentTreasuryAmountValue)
        } else {
            currentTreasuryAmount = nil
        }
        
        if let treasuryDonationPrimitive = primitiveDict[key(CodingKeys.treasuryDonation)] {
            treasuryDonation = try PositiveCoin(from: treasuryDonationPrimitive)
        } else {
            treasuryDonation = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dictionary: OrderedDictionary<Primitive, Primitive> = [:]
        
        func key(_ key: CodingKeys) -> Primitive {
            return .uint(UInt(key.rawValue))
        }
        
        // Required fields
        dictionary[key(CodingKeys.inputs)] = try inputs.toPrimitive()
        dictionary[key(CodingKeys.outputs)] =
            .list(try outputs.map { try $0.toPrimitive() })
        dictionary[key(CodingKeys.fee)] = .uint(UInt(fee))
        
        // Optional fields
        if let ttl = ttl {
            dictionary[key(CodingKeys.ttl)] = .uint(UInt(ttl))
        }
        if let certificates = certificates {
            dictionary[key(CodingKeys.certificates)] = try certificates.toPrimitive()
        }
        if let withdrawals = withdrawals {
            dictionary[key(CodingKeys.withdrawals)] = try withdrawals.toPrimitive()
        }
        if let update = update {
            dictionary[key(CodingKeys.update)] = try update.toPrimitive()
        }
        if let auxiliaryDataHash = auxiliaryDataHash {
            dictionary[key(CodingKeys.auxiliaryDataHash)] = auxiliaryDataHash.toPrimitive()
        }
        if let validityStart = validityStart {
            dictionary[key(CodingKeys.validityStart)] = 
                .uint(UInt(validityStart))
        }
        if let mint = mint {
            dictionary[key(CodingKeys.mint)] = mint.toPrimitive()
        }
        if let scriptDataHash = scriptDataHash {
            dictionary[key(CodingKeys.scriptDataHash)] = scriptDataHash.toPrimitive()
        }
        if let collateral = collateral {
            dictionary[key(CodingKeys.collateral)] = try collateral.toPrimitive()
        }
        if let requiredSigners = requiredSigners {
            dictionary[key(CodingKeys.requiredSigners)] = try requiredSigners.toPrimitive()
        }
        if let networkId = networkId {
            dictionary[key(CodingKeys.networkId)] = .uint(UInt(networkId))
        }
        if let collateralReturn = collateralReturn {
            dictionary[key(CodingKeys.collateralReturn)] = try collateralReturn.toPrimitive()
        }
        if let totalCollateral = totalCollateral {
            dictionary[key(CodingKeys.totalCollateral)] = 
                .uint(UInt(Int(totalCollateral)))
        }
        if let referenceInputs = referenceInputs {
            dictionary[key(CodingKeys.referenceInputs)] = try referenceInputs.toPrimitive()
        }
        if let votingProcedures = votingProcedures {
            dictionary[key(CodingKeys.votingProcedures)] = try votingProcedures.toPrimitive()
        }
        if let proposalProcedures = proposalProcedures {
            dictionary[key(CodingKeys.proposalProcedures)] = try proposalProcedures.toPrimitive()
        }
        if let currentTreasuryAmount = currentTreasuryAmount {
            dictionary[key(CodingKeys.currentTreasuryAmount)] = 
                .uint(UInt(currentTreasuryAmount))
        }
        if let treasuryDonation = treasuryDonation {
            dictionary[key(CodingKeys.treasuryDonation)] = try treasuryDonation.toPrimitive()
        }
        
        return .orderedDict(dictionary)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> TransactionBody {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid TransactionBody dict format")
        }
        // Required fields
        guard let inputsPrimitive = orderedDict[.string(CodingKeys.inputs.stringValue)] else {
            throw CardanoCoreError.deserializeError("Missing inputs in TransactionBody")
        }
        let inputs = try ListOrOrderedSet<TransactionInput>(from: inputsPrimitive)
        
        guard let outputsPrimitive = orderedDict[.string(CodingKeys.outputs.stringValue)],
              case let .list(outputsList) = outputsPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid outputs in TransactionBody")
        }
        let outputs = try outputsList.map { try TransactionOutput(from: $0) }
        
        guard let feePrimitive = orderedDict[.string(CodingKeys.fee.stringValue)],
              case let .int(feeValue) = feePrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid fee in TransactionBody")
        }
        let fee = Coin(feeValue)
        
        // Optional fields
        var ttl: Int? = nil
        if let ttlPrimitive = orderedDict[.string(CodingKeys.ttl.stringValue)],
           case let .int(ttlValue) = ttlPrimitive {
            ttl = ttlValue
        }
        
        var certificates: ListOrNonEmptyOrderedSet<Certificate>? = nil
        if let certificatesPrimitive = orderedDict[.string(CodingKeys.certificates.stringValue)] {
            certificates = try ListOrNonEmptyOrderedSet<Certificate>(from: certificatesPrimitive)
        }
        
        var withdrawals: Withdrawals? = nil
        if let withdrawalsPrimitive = orderedDict[.string(CodingKeys.withdrawals.stringValue)] {
            withdrawals = try Withdrawals(from: withdrawalsPrimitive)
        }
        
        var update: Update? = nil
        if let updatePrimitive = orderedDict[.string(CodingKeys.update.stringValue)] {
            update = try Update(from: updatePrimitive)
        }
        
        var auxiliaryDataHash: AuxiliaryDataHash? = nil
        if let auxiliaryDataHashPrimitive = orderedDict[.string(CodingKeys.auxiliaryDataHash.stringValue)] {
            auxiliaryDataHash = try AuxiliaryDataHash(from: auxiliaryDataHashPrimitive)
        }
        
        var validityStart: Int? = nil
        if let validityStartPrimitive = orderedDict[.string(CodingKeys.validityStart.stringValue)],
           case let .int(validityStartValue) = validityStartPrimitive {
            validityStart = validityStartValue
        }
        
        var mint: MultiAsset? = nil
        if let mintPrimitive = orderedDict[.string(CodingKeys.mint.stringValue)] {
            mint = try MultiAsset(from: mintPrimitive)
        }
        
        var scriptDataHash: ScriptDataHash? = nil
        if let scriptDataHashPrimitive = orderedDict[.string(CodingKeys.scriptDataHash.stringValue)] {
            scriptDataHash = try ScriptDataHash(from: scriptDataHashPrimitive)
        }
        
        var collateral: ListOrNonEmptyOrderedSet<TransactionInput>? = nil
        if let collateralPrimitive = orderedDict[.string(CodingKeys.collateral.stringValue)] {
            collateral = try ListOrNonEmptyOrderedSet<TransactionInput>(from: collateralPrimitive)
        }
        
        var requiredSigners: ListOrNonEmptyOrderedSet<VerificationKeyHash>? = nil
        if let requiredSignersPrimitive = orderedDict[.string(CodingKeys.requiredSigners.stringValue)] {
            requiredSigners = try ListOrNonEmptyOrderedSet<VerificationKeyHash>(from: requiredSignersPrimitive)
        }
        
        var networkId: Int? = nil
        if let networkIdPrimitive = orderedDict[.string(CodingKeys.networkId.stringValue)],
           case let .int(networkIdValue) = networkIdPrimitive {
            networkId = networkIdValue
        }
        
        var collateralReturn: TransactionOutput? = nil
        if let collateralReturnPrimitive = orderedDict[.string(CodingKeys.collateralReturn.stringValue)] {
            collateralReturn = try TransactionOutput(from: collateralReturnPrimitive)
        }
        
        var totalCollateral: Coin? = nil
        if let totalCollateralPrimitive = orderedDict[.string(CodingKeys.totalCollateral.stringValue)],
           case let .int(totalCollateralValue) = totalCollateralPrimitive {
            totalCollateral = Coin(totalCollateralValue)
        }
        
        var referenceInputs: ListOrNonEmptyOrderedSet<TransactionInput>? = nil
        if let referenceInputsPrimitive = orderedDict[.string(CodingKeys.referenceInputs.stringValue)] {
            referenceInputs = try ListOrNonEmptyOrderedSet<TransactionInput>(from: referenceInputsPrimitive)
        }
        
        var votingProcedures: VotingProcedures? = nil
        if let votingProceduresPrimitive = orderedDict[.string(CodingKeys.votingProcedures.stringValue)] {
            votingProcedures = try VotingProcedures(from: votingProceduresPrimitive)
        }
        
        var proposalProcedures: ProposalProcedures? = nil
        if let proposalProceduresPrimitive = orderedDict[.string(CodingKeys.proposalProcedures.stringValue)] {
            proposalProcedures = try ProposalProcedures(from: proposalProceduresPrimitive)
        }
        
        var currentTreasuryAmount: Coin? = nil
        if let currentTreasuryAmountPrimitive = orderedDict[.string(CodingKeys.currentTreasuryAmount.stringValue)],
           case let .int(currentTreasuryAmountValue) = currentTreasuryAmountPrimitive {
            currentTreasuryAmount = Coin(currentTreasuryAmountValue)
        }
        
        var treasuryDonation: PositiveCoin? = nil
        if let treasuryDonationPrimitive = orderedDict[.string(CodingKeys.treasuryDonation.stringValue)] {
            treasuryDonation = try PositiveCoin(from: treasuryDonationPrimitive)
        }
        
        return TransactionBody(
            inputs: inputs,
            outputs: outputs,
            fee: fee,
            ttl: ttl,
            certificates: certificates,
            withdrawals: withdrawals,
            update: update,
            auxiliaryDataHash: auxiliaryDataHash,
            validityStart: validityStart,
            mint: mint,
            scriptDataHash: scriptDataHash,
            collateral: collateral,
            requiredSigners: requiredSigners,
            networkId: networkId,
            collateralReturn: collateralReturn,
            totalCollateral: totalCollateral,
            referenceInputs: referenceInputs,
            votingProcedures: votingProcedures,
            proposalProcedures: proposalProcedures,
            currentTreasuryAmount: currentTreasuryAmount,
            treasuryDonation: treasuryDonation
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        
        // Helper to convert ListOrOrderedSet to list of primitives
        func listOrSetToList<T: CBORSerializable>(_ value: ListOrOrderedSet<T>) throws -> Primitive {
            switch value {
            case .list(let array):
                return .list(try array.map { try $0.toPrimitive() })
            case .orderedSet(let set):
                return .list(try set.elements.map { try $0.toPrimitive() })
            }
        }
        
        // Helper to convert ListOrNonEmptyOrderedSet to list of primitives
        func listOrNonEmptySetToList<T: CBORSerializable>(_ value: ListOrNonEmptyOrderedSet<T>) throws -> Primitive {
            switch value {
            case .list(let array):
                return .list(try array.map { try $0.toPrimitive() })
            case .nonEmptyOrderedSet(let set):
                return .list(try set.elements.map { try $0.toPrimitive() })
            }
        }
        
        // Required fields
        dict[.string(CodingKeys.inputs.stringValue)] = try inputs.toDict()
        dict[.string(CodingKeys.outputs.stringValue)] = .list(try outputs.map( { try $0.toDict() } ))
        dict[.string(CodingKeys.fee.stringValue)] = .int(Int(fee))
        
        // Optional fields
        if let ttl = ttl {
            dict[.string(CodingKeys.ttl.stringValue)] = .int(ttl)
        }
        if let certificates = certificates {
            dict[.string(CodingKeys.certificates.stringValue)] = try certificates.toDict()
        }
        if let withdrawals = withdrawals {
            dict[.string(CodingKeys.withdrawals.stringValue)] = try withdrawals.toDict()
        }
        if let update = update {
            dict[.string(CodingKeys.update.stringValue)] = try update.toDict()
        }
        if let auxiliaryDataHash = auxiliaryDataHash {
            dict[.string(CodingKeys.auxiliaryDataHash.stringValue)] = try auxiliaryDataHash.toDict()
        }
        if let validityStart = validityStart {
            dict[.string(CodingKeys.validityStart.stringValue)] = .int(validityStart)
        }
        if let mint = mint {
            dict[.string(CodingKeys.mint.stringValue)] = try mint.toDict()
        }
        if let scriptDataHash = scriptDataHash {
            dict[.string(CodingKeys.scriptDataHash.stringValue)] = try scriptDataHash.toDict()
        }
        if let collateral = collateral {
            dict[.string(CodingKeys.collateral.stringValue)] = try collateral.toDict()
        }
        if let requiredSigners = requiredSigners {
            dict[.string(CodingKeys.requiredSigners.stringValue)] = try requiredSigners.toDict()
        }
        if let networkId = networkId {
            dict[.string(CodingKeys.networkId.stringValue)] = .int(networkId)
        }
        if let collateralReturn = collateralReturn {
            dict[.string(CodingKeys.collateralReturn.stringValue)] = try collateralReturn.toDict()
        }
        if let totalCollateral = totalCollateral {
            dict[.string(CodingKeys.totalCollateral.stringValue)] = .int(Int(totalCollateral))
        }
        if let referenceInputs = referenceInputs {
            dict[.string(CodingKeys.referenceInputs.stringValue)] = try referenceInputs.toDict()
        }
        if let votingProcedures = votingProcedures {
            dict[.string(CodingKeys.votingProcedures.stringValue)] = try votingProcedures.toDict()
        }
        if let proposalProcedures = proposalProcedures {
            dict[.string(CodingKeys.proposalProcedures.stringValue)] = try proposalProcedures.toDict()
        }
        if let currentTreasuryAmount = currentTreasuryAmount {
            dict[.string(CodingKeys.currentTreasuryAmount.stringValue)] = .int(Int(currentTreasuryAmount))
        }
        if let treasuryDonation = treasuryDonation {
            dict[.string(CodingKeys.treasuryDonation.stringValue)] = try treasuryDonation.toDict()
        }
        
        return .orderedDict(dict)
    }

}
