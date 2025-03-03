import Foundation
import SwiftNcal
import PotentCBOR

public struct TransactionBody: Codable {
    var inputs: [TransactionInput] = []
    var outputs: [TransactionOutput] = []
    var fee: Coin
    var ttl: Int?
    var certificates: [Certificate]?
    var withdrawals: Withdrawals?
    var update: Update?
    var auxiliaryDataHash: AuxiliaryDataHash?
    var validityStart: Int?
    var mint: MultiAsset?
    var scriptDataHash: ScriptDataHash?
    var collateral: [TransactionInput]?
    var requiredSigners: [VerificationKeyHash]?
    var networkId: Int?
    var collateralReturn: TransactionOutput?
    var totalCollateral: Coin?
    var referenceInputs: [TransactionInput]?
    var votingProcedures: VotingProcedure?
    var proposalProcedures: ProposalProcedure?
    var currentTreasuryAmount: Coin?
    var treasuryDonation: PositiveCoin?
    
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
            .count(criteria: { _, _, v in v < _MIN_INT64 || v > _MAX_INT64 }) > 0 {
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
