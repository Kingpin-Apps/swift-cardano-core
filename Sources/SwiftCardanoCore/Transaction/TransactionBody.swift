import Foundation
import SwiftNcal
import PotentCBOR

public struct TransactionBody: CBORSerializable, Equatable, Hashable {
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
        if let mint = mint, try mint
            .count(criteria: { _, _, v in v < Int64.min || v > Int64.max }) > 0 {
            throw CardanoCoreError.invalidArgument("Invalid mint amount: \(mint)")
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
    
    public init(from primitive: Primitive) throws {
        guard case let .dict(primitiveDict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid TransactionBody type")
        }
        
        // Required fields
        guard let inputsPrimitive = primitiveDict[.int(CodingKeys.inputs.rawValue)] else {
            throw CardanoCoreError.deserializeError("TransactionBody inputs are required")
        }
        inputs = try ListOrOrderedSet<TransactionInput>(from: inputsPrimitive)
        
        guard let outputsPrimitive = primitiveDict[.int(CodingKeys.outputs.rawValue)] else {
            throw CardanoCoreError.deserializeError("TransactionBody outputs are required")
        }
        if case let .list(outputsList) = outputsPrimitive {
            outputs = try outputsList.map { try TransactionOutput(from: $0) }
        } else {
            throw CardanoCoreError.deserializeError("TransactionBody outputs must be an array")
        }
        
        guard let feePrimitive = primitiveDict[.int(CodingKeys.fee.rawValue)] else {
            throw CardanoCoreError.deserializeError("TransactionBody fee is required")
        }
        if case let .int(feeValue) = feePrimitive {
            fee = Coin(feeValue)
        } else {
            throw CardanoCoreError.deserializeError("TransactionBody fee must be an integer")
        }
        
        // Optional fields
        if let ttlPrimitive = primitiveDict[.int(CodingKeys.ttl.rawValue)],
           case let .int(ttlValue) = ttlPrimitive {
            ttl = Int(ttlValue)
        } else {
            ttl = nil
        }
        
        if let certificatesPrimitive = primitiveDict[.int(CodingKeys.certificates.rawValue)] {
            certificates = try ListOrNonEmptyOrderedSet<Certificate>(from: certificatesPrimitive)
        } else {
            certificates = nil
        }
        
        if let withdrawalsPrimitive = primitiveDict[.int(CodingKeys.withdrawals.rawValue)] {
            withdrawals = try Withdrawals(from: withdrawalsPrimitive)
        } else {
            withdrawals = nil
        }
        
        if let updatePrimitive = primitiveDict[.int(CodingKeys.update.rawValue)] {
            update = try Update(from: updatePrimitive)
        } else {
            update = nil
        }
        
        if let auxiliaryDataHashPrimitive = primitiveDict[.int(CodingKeys.auxiliaryDataHash.rawValue)] {
            auxiliaryDataHash = try AuxiliaryDataHash(from: auxiliaryDataHashPrimitive)
        } else {
            auxiliaryDataHash = nil
        }
        
        if let validityStartPrimitive = primitiveDict[.int(CodingKeys.validityStart.rawValue)],
           case let .int(validityStartValue) = validityStartPrimitive {
            validityStart = Int(validityStartValue)
        } else {
            validityStart = nil
        }
        
        if let mintPrimitive = primitiveDict[.int(CodingKeys.mint.rawValue)] {
            mint = try MultiAsset(from: mintPrimitive)
        } else {
            mint = nil
        }
        
        if let scriptDataHashPrimitive = primitiveDict[.int(CodingKeys.scriptDataHash.rawValue)] {
            scriptDataHash = try ScriptDataHash(from: scriptDataHashPrimitive)
        } else {
            scriptDataHash = nil
        }
        
        if let collateralPrimitive = primitiveDict[.int(CodingKeys.collateral.rawValue)] {
            collateral = try ListOrNonEmptyOrderedSet<TransactionInput>(from: collateralPrimitive)
        } else {
            collateral = nil
        }
        
        if let requiredSignersPrimitive = primitiveDict[.int(CodingKeys.requiredSigners.rawValue)] {
            requiredSigners = try ListOrNonEmptyOrderedSet<VerificationKeyHash>(from: requiredSignersPrimitive)
        } else {
            requiredSigners = nil
        }
        
        if let networkIdPrimitive = primitiveDict[.int(CodingKeys.networkId.rawValue)],
           case let .int(networkIdValue) = networkIdPrimitive {
            networkId = Int(networkIdValue)
        } else {
            networkId = nil
        }
        
        if let collateralReturnPrimitive = primitiveDict[.int(CodingKeys.collateralReturn.rawValue)] {
            collateralReturn = try TransactionOutput(from: collateralReturnPrimitive)
        } else {
            collateralReturn = nil
        }
        
        if let totalCollateralPrimitive = primitiveDict[.int(CodingKeys.totalCollateral.rawValue)],
           case let .int(totalCollateralValue) = totalCollateralPrimitive {
            totalCollateral = Coin(totalCollateralValue)
        } else {
            totalCollateral = nil
        }
        
        if let referenceInputsPrimitive = primitiveDict[.int(CodingKeys.referenceInputs.rawValue)] {
            referenceInputs = try ListOrNonEmptyOrderedSet<TransactionInput>(from: referenceInputsPrimitive)
        } else {
            referenceInputs = nil
        }
        
        if let votingProceduresPrimitive = primitiveDict[.int(CodingKeys.votingProcedures.rawValue)] {
            votingProcedures = try VotingProcedures(from: votingProceduresPrimitive)
        } else {
            votingProcedures = nil
        }
        
        if let proposalProceduresPrimitive = primitiveDict[.int(CodingKeys.proposalProcedures.rawValue)] {
            proposalProcedures = try ProposalProcedures(from: proposalProceduresPrimitive)
        } else {
            proposalProcedures = nil
        }
        
        if let currentTreasuryAmountPrimitive = primitiveDict[.int(CodingKeys.currentTreasuryAmount.rawValue)],
           case let .int(currentTreasuryAmountValue) = currentTreasuryAmountPrimitive {
            currentTreasuryAmount = Coin(currentTreasuryAmountValue)
        } else {
            currentTreasuryAmount = nil
        }
        
        if let treasuryDonationPrimitive = primitiveDict[.int(CodingKeys.treasuryDonation.rawValue)] {
            treasuryDonation = try PositiveCoin(from: treasuryDonationPrimitive)
        } else {
            treasuryDonation = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var dictionary: [Primitive: Primitive] = [:]
        
        // Required fields
        dictionary[.int(CodingKeys.inputs.rawValue)] = try inputs.toPrimitive()
        dictionary[.int(CodingKeys.outputs.rawValue)] =
            .list(try outputs.map { try $0.toPrimitive() })
        dictionary[.int(CodingKeys.fee.rawValue)] = .int(Int(fee))
        
        // Optional fields
        if let ttl = ttl {
            dictionary[.int(CodingKeys.ttl.rawValue)] = .int(Int(ttl))
        }
        if let certificates = certificates {
            dictionary[.int(4)] = try certificates.toPrimitive()
        }
        if let withdrawals = withdrawals {
            dictionary[.int(5)] = try withdrawals.toPrimitive()
        }
        if let update = update {
            dictionary[.int(6)] = try update.toPrimitive()
        }
        if let auxiliaryDataHash = auxiliaryDataHash {
            dictionary[.int(7)] = auxiliaryDataHash.toPrimitive()
        }
        if let validityStart = validityStart {
            dictionary[.int(8)] = .int(Int(validityStart))
        }
        if let mint = mint {
            dictionary[.int(9)] = mint.toPrimitive()
        }
        if let scriptDataHash = scriptDataHash {
            dictionary[.int(11)] = scriptDataHash.toPrimitive()
        }
        if let collateral = collateral {
            dictionary[.int(13)] = try collateral.toPrimitive()
        }
        if let requiredSigners = requiredSigners {
            dictionary[.int(14)] = try requiredSigners.toPrimitive()
        }
        if let networkId = networkId {
            dictionary[.int(15)] = .int(Int(networkId))
        }
        if let collateralReturn = collateralReturn {
            dictionary[.int(16)] = try collateralReturn.toPrimitive()
        }
        if let totalCollateral = totalCollateral {
            dictionary[.int(17)] = .int(Int(totalCollateral))
        }
        if let referenceInputs = referenceInputs {
            dictionary[.int(18)] = try referenceInputs.toPrimitive()
        }
        if let votingProcedures = votingProcedures {
            dictionary[.int(19)] = try votingProcedures.toPrimitive()
        }
        if let proposalProcedures = proposalProcedures {
            dictionary[.int(20)] = try proposalProcedures.toPrimitive()
        }
        if let currentTreasuryAmount = currentTreasuryAmount {
            dictionary[.int(21)] = .int(Int(currentTreasuryAmount))
        }
        if let treasuryDonation = treasuryDonation {
            dictionary[.int(22)] = try treasuryDonation.toPrimitive()
        }
        
        return .dict(dictionary)
    }
}
