import Foundation
import SwiftNcal
import PotentCBOR

struct TransactionBody: Codable {
    var inputs: [TransactionInput] = []
    var outputs: [TransactionOutput] = []
    var fee: Coin
    var ttl: Int?
    var certificates: [Certificate]?
    var withdraws: Withdrawals?
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
        case withdraws = 5
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
    
    init(from decoder: Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        inputs = try container.decode([TransactionInput].self, forKey: .inputs)
        outputs = try container.decode([TransactionOutput].self, forKey: .outputs)
        fee = try container.decode(Coin.self, forKey: .fee)
        ttl = try container.decodeIfPresent(Int.self, forKey: .ttl)
        certificates = try container.decodeIfPresent([Certificate].self, forKey: .certificates)
        update = try container.decodeIfPresent(Update.self, forKey: .update)
        withdraws = try container.decodeIfPresent(Withdrawals.self, forKey: .withdraws)
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

    func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(fee, forKey: .fee)
        try container.encodeIfPresent(ttl, forKey: .ttl)
        try container.encodeIfPresent(certificates, forKey: .certificates)
        try container.encodeIfPresent(update, forKey: .update)
        try container.encodeIfPresent(withdraws, forKey: .withdraws)
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
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let dict = value as? [Int: Any] else {
//            throw CardanoCoreError.valueError("Expected dictionary for deserialization.")
//        }
//        
//        var inputs: [TransactionInput] = []
//        var outputs: [TransactionOutput] = []
//        var fee: Coin = 0
//        var ttl: Int? = nil
//        var certificates: [Certificate]? = nil
//        var withdraws: Withdrawals? = nil
//        var auxiliaryDataHash: AuxiliaryDataHash? = nil
//        var validityStart: Int? = nil
//        var mint: MultiAsset? = nil
//        var scriptDataHash: ScriptDataHash? = nil
//        var collateral: [TransactionInput]? = nil
//        var requiredSigners: [VerificationKeyHash]? = nil
//        var networkId: Int? = nil
//        var collateralReturn: TransactionOutput? = nil
//        var totalCollateral: Coin? = nil
//        var referenceInputs: [TransactionInput]? = nil
//        var votingProcedures: VotingProcedure? = nil
//        var proposalProcedures: ProposalProcedure? = nil
//        var currentTreasuryAmount: Coin? = nil
//        var treasuryDonation: PositiveCoin? = nil
//        
//        for (key, rawValue) in dict {
//            switch key {
//            case 0:
//                inputs = try (rawValue as? [Any])?.map {
//                    try TransactionInput.fromPrimitive($0)
//                } ?? []
//            case 1:
//                outputs = try (rawValue as? [Any])?.map {
//                    try TransactionOutput.fromPrimitive($0)
//                } ?? []
//            case 2:
//                fee = rawValue as? Coin ?? 0
//            case 3:
//                ttl = rawValue as? Int
//            case 4:
//                certificates = try (rawValue as? [Any])?.map {
//                    try Certificate.fromPrimitive($0)
//                }
//            case 5:
//                withdraws = try Withdrawals.fromPrimitive(rawValue)
//            case 7:
//                auxiliaryDataHash = try AuxiliaryDataHash.fromPrimitive(rawValue)
//            case 8:
//                validityStart = rawValue as? Int
//            case 9:
//                mint = try MultiAsset.fromPrimitive(rawValue)
//            case 11:
//                scriptDataHash = try ScriptDataHash.fromPrimitive(rawValue)
//            case 13:
//                collateral = try (rawValue as? [Any])?.map {
//                    try TransactionInput.fromPrimitive($0)
//                }
//            case 14:
//                requiredSigners = try (rawValue as? [Any])?.map {
//                    try VerificationKeyHash.fromPrimitive($0)
//                }
//            case 15:
//                networkId = rawValue as? Int
//            case 16:
//                collateralReturn = try TransactionOutput.fromPrimitive(rawValue)
//            case 17:
//                totalCollateral = rawValue as? Coin
//            case 18:
//                referenceInputs = try (rawValue as? [Any])?.map {
//                    try TransactionInput.fromPrimitive($0)
//                }
//            case 19:
//                votingProcedures = try VotingProcedure.fromPrimitive(rawValue)
//            case 20:
//                proposalProcedures = try ProposalProcedure.fromPrimitive(rawValue)
//            case 21:
//                currentTreasuryAmount = rawValue as? Coin
//            case 22:
//                treasuryDonation = rawValue as? PositiveCoin
//            default:
//                throw CardanoCoreError.valueError("Unexpected key \(key) in transaction body deserialization.")
//            }
//        }
//        
//        return TransactionBody(
//            inputs: inputs,
//            outputs: outputs,
//            fee: fee,
//            ttl: ttl,
//            certificates: certificates,
//            withdraws: withdraws,
//            update: nil, // Handle if needed
//            auxiliaryDataHash: auxiliaryDataHash,
//            validityStart: validityStart,
//            mint: mint,
//            scriptDataHash: scriptDataHash,
//            collateral: collateral,
//            requiredSigners: requiredSigners,
//            networkId: networkId,
//            collateralReturn: collateralReturn,
//            totalCollateral: totalCollateral,
//            referenceInputs: referenceInputs,
//            votingProcedures: votingProcedures,
//            proposalProcedures: proposalProcedures,
//            currentTreasuryAmount: currentTreasuryAmount,
//            treasuryDonation: treasuryDonation
//        ) as! T
//    }

    func validate() throws {
        if let mint = mint, try mint
            .count(criteria: { _, _, v in v < _MIN_INT64 || v > _MAX_INT64 }) > 0 {
            throw CardanoCoreError.invalidArgument("Invalid mint amount: \(mint)")
        }
    }

    var id: TransactionId {
        return try! TransactionId(payload: hash())
    }
    
    func hash() -> Data {
        return try! Hash().blake2b(
            data: try CBOREncoder().encode(self),
            digestSize: TRANSACTION_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
