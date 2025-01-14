import Foundation
import CryptoKit
import SwiftNcal

// Definitions of transaction-related data types.

let _MAX_INT64: Int64 = (1 << 63) - 1
let _MIN_INT64: Int64 = -(1 << 63)

struct TransactionInput: ArrayCBORSerializable, Hashable {
    let transactionId: TransactionId
    let index: UInt16
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let value = value as? [Any] else {
            throw CardanoCoreError.valueError("Expected dictionary for deserialization.")
        }
        
        let transactionId: TransactionId = try TransactionId.fromPrimitive(value[0])
        let index = value[1] as! UInt16
        
        return TransactionInput(
            transactionId: transactionId,
            index: index
        ) as! T
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(transactionId)
        hasher.combine(index)
    }
}

struct TransactionOutput: CBORSerializable, Hashable, Equatable {
    var address: Address
    var amount: Value
    var datumHash: DatumHash?
    var datum: Datum?
    var script: ScriptType?
    var postAlonzo: Bool = true

    var lovelace: Int {
        return amount.coin
    }

    func validate() throws {
        if amount.coin < 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of ADA: \(amount)")
        }
        if try amount.multiAsset.count(criteria: { _, _, v in v < 0 }) > 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of tokens or native assets: \(amount)")
        }
    }
    
    func toShallowPrimitive() throws -> Any {
        if datum != nil || script != nil || postAlonzo {
            let datumOption: DatumOption? = {
                if let datum = datum {
                    return DatumOption(datum: datum)
                } else if let datumHash = datumHash {
                    return DatumOption(datum: datumHash)
                }
                return nil
            }()

            let scriptRef: ScriptRef? = {
                if let script = script {
                    return ScriptRef(script: Script(script: script))
                }
                return nil
            }()
            
            return BabbageTransactionOutput(
                address: address,
                amount: amount,
                datum: datumOption,
                scriptRef: scriptRef
            ).toShallowPrimitive()
        } else {
            // Assuming a structure similar to _TransactionOutputLegacy
            return ShelleyTransactionOutput(
                address: address,
                amount: amount,
                datumHash: datumHash
            ).toShallowPrimitive()
        }
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        if let list = value as? [Any] {
            let output: ShelleyTransactionOutput = try ShelleyTransactionOutput.fromPrimitive(list)
            return TransactionOutput(
                address: output.address,
                amount: output.amount,
                datumHash: output.datumHash
            ) as! T
        } else if let dict = value as? [String: Any] {
            let output: BabbageTransactionOutput = try BabbageTransactionOutput.fromPrimitive(dict)
            let datum = output.datum?.datum
            if let datum = datum as? DatumHash {
                return TransactionOutput(
                    address: output.address,
                    amount: output.amount,
                    datumHash: datum
                ) as! T
            } else {
                return TransactionOutput(
                    address: output.address,
                    amount: output.amount,
                    datum: datum as? Datum,
                    script: output.script
                ) as! T
            }
                
        }
        
        throw CardanoCoreError.valueError("Invalid transaction output data: \(value)")
        
    }
    
    static func == (lhs: TransactionOutput, rhs: TransactionOutput) -> Bool {
        return lhs.address == rhs.address &&
        lhs.amount == rhs.amount &&
        lhs.datumHash == rhs.datumHash &&
        lhs.datum == rhs.datum &&
        lhs.script == rhs.script &&
        lhs.postAlonzo == rhs.postAlonzo
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(amount)
        hasher.combine(datumHash)
        hasher.combine(datum)
        hasher.combine(script)
    }
}

struct TransactionBody: MapCBORSerializable {
    var inputs: [TransactionInput] = []
    var outputs: [TransactionOutput] = []
    var fee: Coin
    var ttl: Int?
    var certificates: [Certificate]?
    var withdraws: Withdrawals?
    var update: Any?
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
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let dict = value as? [Int: Any] else {
            throw CardanoCoreError.valueError("Expected dictionary for deserialization.")
        }
        
        var inputs: [TransactionInput] = []
        var outputs: [TransactionOutput] = []
        var fee: Coin = 0
        var ttl: Int? = nil
        var certificates: [Certificate]? = nil
        var withdraws: Withdrawals? = nil
        var auxiliaryDataHash: AuxiliaryDataHash? = nil
        var validityStart: Int? = nil
        var mint: MultiAsset? = nil
        var scriptDataHash: ScriptDataHash? = nil
        var collateral: [TransactionInput]? = nil
        var requiredSigners: [VerificationKeyHash]? = nil
        var networkId: Int? = nil
        var collateralReturn: TransactionOutput? = nil
        var totalCollateral: Coin? = nil
        var referenceInputs: [TransactionInput]? = nil
        var votingProcedures: VotingProcedure? = nil
        var proposalProcedures: ProposalProcedure? = nil
        var currentTreasuryAmount: Coin? = nil
        var treasuryDonation: PositiveCoin? = nil
        
        for (key, rawValue) in dict {
            switch key {
            case 0:
                inputs = try (rawValue as? [Any])?.map {
                    try TransactionInput.fromPrimitive($0)
                } ?? []
            case 1:
                outputs = try (rawValue as? [Any])?.map {
                    try TransactionOutput.fromPrimitive($0)
                } ?? []
            case 2:
                fee = rawValue as? Coin ?? 0
            case 3:
                ttl = rawValue as? Int
            case 4:
                certificates = try (rawValue as? [Any])?.map {
                    try Certificate.fromPrimitive($0)
                }
            case 5:
                withdraws = try Withdrawals.fromPrimitive(rawValue)
            case 7:
                auxiliaryDataHash = try AuxiliaryDataHash.fromPrimitive(rawValue)
            case 8:
                validityStart = rawValue as? Int
            case 9:
                mint = try MultiAsset.fromPrimitive(rawValue)
            case 11:
                scriptDataHash = try ScriptDataHash.fromPrimitive(rawValue)
            case 13:
                collateral = try (rawValue as? [Any])?.map {
                    try TransactionInput.fromPrimitive($0)
                }
            case 14:
                requiredSigners = try (rawValue as? [Any])?.map {
                    try VerificationKeyHash.fromPrimitive($0)
                }
            case 15:
                networkId = rawValue as? Int
            case 16:
                collateralReturn = try TransactionOutput.fromPrimitive(rawValue)
            case 17:
                totalCollateral = rawValue as? Coin
            case 18:
                referenceInputs = try (rawValue as? [Any])?.map {
                    try TransactionInput.fromPrimitive($0)
                }
            case 19:
                votingProcedures = try VotingProcedure.fromPrimitive(rawValue)
            case 20:
                proposalProcedures = try ProposalProcedure.fromPrimitive(rawValue)
            case 21:
                currentTreasuryAmount = rawValue as? Coin
            case 22:
                treasuryDonation = rawValue as? PositiveCoin
            default:
                throw CardanoCoreError.valueError("Unexpected key \(key) in transaction body deserialization.")
            }
        }
        
        return TransactionBody(
            inputs: inputs,
            outputs: outputs,
            fee: fee,
            ttl: ttl,
            certificates: certificates,
            withdraws: withdraws,
            update: nil, // Handle if needed
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
        ) as! T
    }

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
            data: toCBOR(),
            digestSize: TRANSACTION_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}

struct Transaction: ArrayCBORSerializable {
    var transactionBody: TransactionBody
    var transactionWitnessSet: TransactionWitnessSet
    var valid: Bool = true
    var auxiliaryData: AuxiliaryData? = nil

    var id: TransactionId? {
        return transactionBody.id
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any] else {
            throw CardanoCoreError.valueError("Invalid transaction data: \(value)")
        }
        
        let transactionBody: TransactionBody = try TransactionBody.fromPrimitive(list[0])
        let transactionWitnessSet: TransactionWitnessSet = try TransactionWitnessSet.fromPrimitive(list[1])
        let valid = list[2] as? Bool ?? true
        let auxiliaryData: AuxiliaryData? = list.count > 3 ? try AuxiliaryData.fromPrimitive(list[3]) : nil
        
        return Transaction(
            transactionBody: transactionBody,
            transactionWitnessSet: transactionWitnessSet,
            valid: valid,
            auxiliaryData: auxiliaryData
        ) as! T
    }
}



/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
class Withdrawals: DictCBORSerializable {
    typealias KEY_TYPE = Data
    typealias VALUE_TYPE = Int
}
