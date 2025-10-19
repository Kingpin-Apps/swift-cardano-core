import Foundation
import SwiftNcal
import PotentCBOR
import OrderedCollections

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
}
