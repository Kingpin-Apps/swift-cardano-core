import Foundation
import OrderedCollections
import SwiftNaCl

/// Cardano block as defined in the Conway CDDL:
/// ```
/// block =
///   [ header
///   , transaction_bodies       : [* transaction_body]
///   , transaction_witness_sets : [* transaction_witness_set]
///   , auxiliary_data_set       : {* transaction_index => auxiliary_data}
///   , invalid_transactions     : [* transaction_index]
///   ]
/// ```
///
/// Serialized as a CBOR array with 5 elements.
public struct Block: Serializable {
    /// Block header containing metadata and KES signature
    public var header: Header
    /// Transaction bodies in this block
    public var transactionBodies: [TransactionBody]
    /// Witness sets corresponding to each transaction
    public var transactionWitnessSets: [TransactionWitnessSet]
    /// Auxiliary data keyed by transaction index
    public var auxiliaryDataSet: OrderedDictionary<TransactionIndex, AuxiliaryData>
    /// Indices of invalid transactions within this block
    public var invalidTransactions: [TransactionIndex]

    enum CodingKeys: String, CodingKey {
        case header
        case transactionBodies
        case transactionWitnessSets
        case auxiliaryDataSet
        case invalidTransactions
    }

    public init(
        header: Header,
        transactionBodies: [TransactionBody],
        transactionWitnessSets: [TransactionWitnessSet],
        auxiliaryDataSet: OrderedDictionary<TransactionIndex, AuxiliaryData> = [:],
        invalidTransactions: [TransactionIndex] = []
    ) {
        self.header = header
        self.transactionBodies = transactionBodies
        self.transactionWitnessSets = transactionWitnessSets
        self.auxiliaryDataSet = auxiliaryDataSet
        self.invalidTransactions = invalidTransactions
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let l): elements = l
        case .indefiniteList(let l): elements = Array(l)
        default:
            throw CardanoCoreError.deserializeError("Invalid Block primitive: expected list")
        }

        guard elements.count == 5 else {
            throw CardanoCoreError.deserializeError(
                "Block requires exactly 5 elements, got \(elements.count)"
            )
        }

        // 0: header
        self.header = try Header(from: elements[0])

        // 1: transaction_bodies : [* transaction_body]
        let txBodyPrimitives: [Primitive]
        switch elements[1] {
        case .list(let l): txBodyPrimitives = l
        case .indefiniteList(let l): txBodyPrimitives = Array(l)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block transaction_bodies: expected list")
        }
        self.transactionBodies = try txBodyPrimitives.map { try TransactionBody(from: $0) }

        // 2: transaction_witness_sets : [* transaction_witness_set]
        let txWitnessPrimitives: [Primitive]
        switch elements[2] {
        case .list(let l): txWitnessPrimitives = l
        case .indefiniteList(let l): txWitnessPrimitives = Array(l)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block transaction_witness_sets: expected list")
        }
        self.transactionWitnessSets = try txWitnessPrimitives.map {
            if case .cborTag(let tagged) = $0 {
                return try TransactionWitnessSet(from: tagged.value)
            }
            return try TransactionWitnessSet(from: $0)
        }

        // 3: auxiliary_data_set : {* transaction_index => auxiliary_data}
        self.auxiliaryDataSet = OrderedDictionary<TransactionIndex, AuxiliaryData>()
        switch elements[3] {
        case .orderedDict(let dict):
            for (key, value) in dict {
                let index: TransactionIndex
                switch key {
                case .uint(let val): index = TransactionIndex(val)
                case .int(let val): index = TransactionIndex(val)
                default:
                    throw CardanoCoreError.deserializeError(
                        "Invalid auxiliary_data_set key type"
                    )
                }
                self.auxiliaryDataSet[index] = try AuxiliaryData(from: value)
            }
        case .dict(let dict):
            for (key, value) in dict {
                let index: TransactionIndex
                switch key {
                case .uint(let val): index = TransactionIndex(val)
                case .int(let val): index = TransactionIndex(val)
                default:
                    throw CardanoCoreError.deserializeError(
                        "Invalid auxiliary_data_set key type"
                    )
                }
                self.auxiliaryDataSet[index] = try AuxiliaryData(from: value)
            }
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block auxiliary_data_set: expected dict"
            )
        }

        // 4: invalid_transactions : [* transaction_index]
        let invalidTxPrimitives: [Primitive]
        switch elements[4] {
        case .list(let l): invalidTxPrimitives = l
        case .indefiniteList(let l): invalidTxPrimitives = Array(l)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block invalid_transactions: expected list")
        }
        self.invalidTransactions = try invalidTxPrimitives.map { element in
            switch element {
            case .uint(let val): return TransactionIndex(val)
            case .int(let val): return TransactionIndex(val)
            default:
                throw CardanoCoreError.deserializeError(
                    "Invalid transaction_index type in invalid_transactions"
                )
            }
        }
    }

    public func toPrimitive() throws -> Primitive {
        // transaction_bodies
        let txBodies: [Primitive] = try transactionBodies.map { try $0.toPrimitive() }

        // transaction_witness_sets
        let txWitnesses: [Primitive] = try transactionWitnessSets.map { try $0.toPrimitive() }

        // auxiliary_data_set
        var auxDataDict = OrderedDictionary<Primitive, Primitive>()
        for (index, auxData) in auxiliaryDataSet {
            auxDataDict[.uint(UInt64(index))] = try auxData.toPrimitive()
        }

        // invalid_transactions
        let invalidTxs: [Primitive] = invalidTransactions.map { .uint(UInt64($0)) }

        return .list([
            try header.toPrimitive(),
            .list(txBodies),
            .list(txWitnesses),
            .orderedDict(auxDataDict),
            .list(invalidTxs),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> Block {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Block dict")
        }

        guard let headerPrimitive = dict[.string(CodingKeys.header.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing header in Block")
        }
        let header = try Header.fromDict(headerPrimitive)

        guard let txBodiesPrimitive = dict[.string(CodingKeys.transactionBodies.rawValue)],
            case .list(let txBodyList) = txBodiesPrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Missing or invalid transactionBodies in Block"
            )
        }
        let transactionBodies = try txBodyList.map { try TransactionBody.fromDict($0) }

        guard
            let txWitnessesPrimitive = dict[
                .string(CodingKeys.transactionWitnessSets.rawValue)
            ],
            case .list(let txWitnessList) = txWitnessesPrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Missing or invalid transactionWitnessSets in Block"
            )
        }
        let transactionWitnessSets = try txWitnessList.map {
            try TransactionWitnessSet.fromDict($0)
        }

        var auxiliaryDataSet = OrderedDictionary<TransactionIndex, AuxiliaryData>()
        if let auxDataPrimitive = dict[.string(CodingKeys.auxiliaryDataSet.rawValue)],
            case .orderedDict(let auxDict) = auxDataPrimitive
        {
            for (key, value) in auxDict {
                let index: TransactionIndex
                switch key {
                case .uint(let val): index = TransactionIndex(val)
                case .int(let val): index = TransactionIndex(val)
                case .string(let str):
                    guard let val = UInt16(str) else {
                        throw CardanoCoreError.deserializeError(
                            "Invalid auxiliary_data_set key string"
                        )
                    }
                    index = val
                default:
                    throw CardanoCoreError.deserializeError(
                        "Invalid auxiliary_data_set key type in dict"
                    )
                }
                auxiliaryDataSet[index] = try AuxiliaryData.fromDict(value)
            }
        }

        var invalidTransactions: [TransactionIndex] = []
        if let invalidTxPrimitive = dict[.string(CodingKeys.invalidTransactions.rawValue)],
            case .list(let invalidTxList) = invalidTxPrimitive
        {
            invalidTransactions = try invalidTxList.map { element in
                switch element {
                case .uint(let val): return TransactionIndex(val)
                case .int(let val): return TransactionIndex(val)
                default:
                    throw CardanoCoreError.deserializeError(
                        "Invalid transaction_index type in dict"
                    )
                }
            }
        }

        return Block(
            header: header,
            transactionBodies: transactionBodies,
            transactionWitnessSets: transactionWitnessSets,
            auxiliaryDataSet: auxiliaryDataSet,
            invalidTransactions: invalidTransactions
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        dict[.string(CodingKeys.header.rawValue)] = try header.toDict()
        dict[.string(CodingKeys.transactionBodies.rawValue)] = .list(
            try transactionBodies.map { try $0.toDict() }
        )
        dict[.string(CodingKeys.transactionWitnessSets.rawValue)] = .list(
            try transactionWitnessSets.map { try $0.toDict() }
        )

        var auxDict = OrderedDictionary<Primitive, Primitive>()
        for (index, auxData) in auxiliaryDataSet {
            auxDict[.uint(UInt64(index))] = try auxData.toDict()
        }
        dict[.string(CodingKeys.auxiliaryDataSet.rawValue)] = .orderedDict(auxDict)

        dict[.string(CodingKeys.invalidTransactions.rawValue)] = .list(
            invalidTransactions.map { .uint(UInt64($0)) }
        )

        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: Block, rhs: Block) -> Bool {
        return lhs.header == rhs.header && lhs.transactionBodies == rhs.transactionBodies
            && lhs.transactionWitnessSets == rhs.transactionWitnessSets
            && lhs.auxiliaryDataSet == rhs.auxiliaryDataSet
            && lhs.invalidTransactions == rhs.invalidTransactions
    }

    // MARK: - Hashable
    
    public func hash() -> Data {
        return try! Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: BLOCK_BODY_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
