import Foundation
import CryptoKit
import SwiftNcal

// Definitions of transaction-related data types.

let _MAX_INT64: Int64 = (1 << 63) - 1
let _MIN_INT64: Int64 = -(1 << 63)

struct TransactionInput: ArrayCBORSerializable, Hashable {
    let transactionId: Data
    let index: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(transactionId)
        hasher.combine(index)
    }
}

struct TransactionOutput: CBORSerializable, Hashable {
    var address: String
    var amount: Value
    var datumHash: Data?
    var datum: Any?
    var script: Any?
    var postAlonzo: Bool = false

    init(address: String, amount: Value, datumHash: Data? = nil, datum: Any? = nil, script: Any? = nil, postAlonzo: Bool = false) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
        self.datum = datum
        self.script = script
        self.postAlonzo = postAlonzo
    }

    var lovelace: Int {
        return amount.coin
    }

    func validate() throws {
        if amount.coin < 0 {
            throw NSError(domain: "InvalidDataException", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction output cannot have negative amount of ADA or native asset: \(amount)"])
        }
        if amount.multiAsset.count(criteria: { _, _, v in v < 0 }) > 0 {
            throw NSError(domain: "InvalidDataException", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction output cannot have negative amount of ADA or native asset: \(amount)"])
        }
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

    func validate() throws {
        if let mint = mint, mint.count(criteria: { _, _, v in v < _MIN_INT64 || v > _MAX_INT64 }) > 0 {
            throw NSError(domain: "InvalidDataException", code: 0, userInfo: [NSLocalizedDescriptionKey: "Mint amount must be between \(_MIN_INT64) and \(_MAX_INT64). Mint amount: \(mint)"])
        }
    }

    var id: TransactionId {
        return TransactionId(payload: try! hash())
    }
    
    func hash() -> Data {
        return try! Hash().blake2b(
            data: toCBOR(),
            digestSize: TRANSACTION_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}

struct Transaction: ArrayCBORSerializable, Hashable {
    var transactionBody: TransactionBody
    var transactionWitnessSet: TransactionWitnessSet
    var valid: Bool = true
    var auxiliaryData: AuxiliaryData? = nil

    var id: TransactionId? {
        return transactionBody.id
    }
}


class TransactionOutputLegacy: ArrayCBORSerializable {
    var address: Address
    var amount: Any
    var datumHash: DatumHash?

    init(address: Address, amount: Any, datumHash: DatumHash? = nil) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
    }

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case datumHash
    }
}

class TransactionOutputPostAlonzo: MapCBORSerializable {
    var address: Address
    var amount: Any
    var datum: DatumOption?
    var scriptRef: ScriptRef?

    init(address: Address, amount: Any, datum: DatumOption? = nil, scriptRef: ScriptRef? = nil) {
        self.address = address
        self.amount = amount
        self.datum = datum
        self.scriptRef = scriptRef
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case datum
        case scriptRef
    }

    var script: Any? {
        return scriptRef?.script.script
    }
}

/// A disctionary of reward addresses to reward withdrawal amount.
///
/// Key is address bytes, value is an integer.
struct Withdrawals: DictCBORSerializable {
    typealias KEY_TYPE = Data
    typealias VALUE_TYPE = Int
}
