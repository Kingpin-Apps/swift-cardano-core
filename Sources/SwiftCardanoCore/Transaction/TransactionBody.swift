import Foundation
import SwiftNcal
import PotentCBOR

public struct TransactionBody: CBORSerializable, Equatable, Hashable {
    public var inputs: [TransactionInput]
    public var outputs: [TransactionOutput]
    public var fee: Coin
    public var ttl: Int?
    public var certificates: [Certificate]?
    public var withdrawals: Withdrawals?
    public var update: Update?
    public var auxiliaryDataHash: AuxiliaryDataHash?
    public var validityStart: Int?
    public var mint: MultiAsset?
    public var scriptDataHash: ScriptDataHash?
    public var collateral: [TransactionInput]?
    public var requiredSigners: [VerificationKeyHash]?
    public var networkId: Int?
    public var collateralReturn: TransactionOutput?
    public var totalCollateral: Coin?
    public var referenceInputs: [TransactionInput]?
    public var votingProcedures: VotingProcedure?
    public var proposalProcedures: ProposalProcedure?
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
        inputs: [TransactionInput],
        outputs: [TransactionOutput],
        fee: Coin,
        ttl: Int? = nil,
        certificates: [Certificate]? = nil,
        withdrawals: Withdrawals? = nil,
        update: Update? = nil,
        auxiliaryDataHash: AuxiliaryDataHash? = nil,
        validityStart: Int? = nil,
        mint: MultiAsset? = nil,
        scriptDataHash: ScriptDataHash? = nil,
        collateral: [TransactionInput]? = nil,
        requiredSigners: [VerificationKeyHash]? = nil,
        networkId: Int? = nil,
        collateralReturn: TransactionOutput? = nil,
        totalCollateral: Coin? = nil,
        referenceInputs: [TransactionInput]? = nil,
        votingProcedures: VotingProcedure? = nil,
        proposalProcedures: ProposalProcedure? = nil,
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputs = try container.decode([TransactionInput].self, forKey: .inputs)
        outputs = try container.decode([TransactionOutput].self, forKey: .outputs)
        fee = try container.decode(Coin.self, forKey: .fee)
        ttl = try container.decodeIfPresent(Int.self, forKey: .ttl)
        certificates = try container.decodeIfPresent([Certificate].self, forKey: .certificates)
        update = try container.decodeIfPresent(Update.self, forKey: .update)
        withdrawals = try container.decodeIfPresent(Withdrawals.self, forKey: .withdrawals)
        auxiliaryDataHash = try container.decodeIfPresent(AuxiliaryDataHash.self, forKey: .auxiliaryDataHash)
        validityStart = try container.decodeIfPresent(Int.self, forKey: .validityStart)
        mint = try container.decodeIfPresent(MultiAsset.self, forKey: .mint)
        scriptDataHash = try container.decodeIfPresent(ScriptDataHash.self, forKey: .scriptDataHash)
        collateral = try container.decodeIfPresent([TransactionInput].self, forKey: .collateral)
        requiredSigners = try container.decodeIfPresent([VerificationKeyHash].self, forKey: .requiredSigners)
        networkId = try container.decodeIfPresent(Int.self, forKey: .networkId)
        collateralReturn = try container.decodeIfPresent(TransactionOutput.self, forKey: .collateralReturn)
        totalCollateral = try container.decodeIfPresent(Coin.self, forKey: .totalCollateral)
        referenceInputs = try container.decodeIfPresent([TransactionInput].self, forKey: .referenceInputs)
        votingProcedures = try container.decodeIfPresent(VotingProcedure.self, forKey: .votingProcedures)
        proposalProcedures = try container.decodeIfPresent(ProposalProcedure.self, forKey: .proposalProcedures)
        currentTreasuryAmount = try container.decodeIfPresent(Coin.self, forKey: .currentTreasuryAmount)
        treasuryDonation = try container.decodeIfPresent(PositiveCoin.self, forKey: .treasuryDonation)
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(fee, forKey: .fee)
        try container.encodeIfPresent(ttl, forKey: .ttl)
        try container.encodeIfPresent(certificates, forKey: .certificates)
        try container.encodeIfPresent(update, forKey: .update)
        try container.encodeIfPresent(withdrawals, forKey: .withdrawals)
        try container.encodeIfPresent(auxiliaryDataHash, forKey: .auxiliaryDataHash)
        try container.encodeIfPresent(validityStart, forKey: .validityStart)
        try container.encodeIfPresent(mint, forKey: .mint)
        try container.encodeIfPresent(scriptDataHash, forKey: .scriptDataHash)
        try container.encodeIfPresent(collateral, forKey: .collateral)
        try container.encodeIfPresent(requiredSigners, forKey: .requiredSigners)
        try container.encodeIfPresent(networkId, forKey: .networkId)
        try container.encodeIfPresent(collateralReturn, forKey: .collateralReturn)
        try container.encodeIfPresent(totalCollateral, forKey: .totalCollateral)
        try container.encodeIfPresent(referenceInputs, forKey: .referenceInputs)
        try container.encodeIfPresent(votingProcedures, forKey: .votingProcedures)
        try container.encodeIfPresent(proposalProcedures, forKey: .proposalProcedures)
        try container.encodeIfPresent(currentTreasuryAmount, forKey: .currentTreasuryAmount)
        try container.encodeIfPresent(treasuryDonation, forKey: .treasuryDonation)
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
            data: try CBOREncoder().encode(self),
            digestSize: TRANSACTION_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
