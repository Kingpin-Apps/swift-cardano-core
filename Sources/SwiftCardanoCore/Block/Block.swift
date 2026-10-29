import Foundation
import CBORCodable
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
    public var header: Header { didSet { originalCBOR = nil } }
    /// Transaction bodies in this block
    public var transactionBodies: [TransactionBody] { didSet { originalCBOR = nil } }
    /// Witness sets corresponding to each transaction
    public var transactionWitnessSets: [TransactionWitnessSet] { didSet { originalCBOR = nil } }
    /// Auxiliary data keyed by transaction index
    public var auxiliaryDataSet: OrderedDictionary<TransactionIndex, AuxiliaryData> {
        didSet { originalCBOR = nil }
    }
    /// Indices of invalid transactions within this block
    public var invalidTransactions: [TransactionIndex] { didSet { originalCBOR = nil } }

    /// Whether this was written in the Shelley to Mary shape, `[header,
    /// bodies, witness sets, auxiliary data]`, which has no invalid
    /// transactions.
    public internal(set) var isPreAlonzo = false { didSet { originalCBOR = nil } }

    /// The exact bytes this block was decoded from, while it is unchanged.
    ///
    /// Its header, transaction bodies, witness sets and auxiliary data keep
    /// their own bytes too, so the block hash and every transaction id — and
    /// the datums, redeemers and metadata those commit to — are those of what
    /// was written, not of a re-encoding.
    public internal(set) var originalCBOR: Data? = nil

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

    /// Decodes a block as the current era's ledger reads it, keeping the bytes
    /// of it and of its parts.
    public static func fromCBOR(data: Data) throws -> Block {
        try fromCBOR(data: data, era: .conway)
    }

    /// Decodes a block of `era` as that era's ledger reads it, keeping the
    /// bytes of it and of its parts.
    public static func fromCBOR(data: Data, era: Era) throws -> Block {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after Block")
        }
        let bytes = scanner.bytes
        let spans = try scanner.elements(ofArrayAt: 0)
        guard spans.count == 4 || spans.count == 5 else {
            throw CardanoCoreError.deserializeError("Block requires 4 or 5 elements, got \(spans.count)")
        }
        let rules = LedgerDuplicateRules(bytes, era: era)
        let bodySpans = try scanner.elements(ofArrayAt: spans[1].lowerBound)
        let witnessSpans = try scanner.elements(ofArrayAt: spans[2].lowerBound)
        let auxiliaryEntries = try scanner.entries(ofMapAt: spans[3].lowerBound)
        for span in bodySpans { try rules.checkBody(at: span.lowerBound) }
        for span in witnessSpans { try rules.checkWitnessSet(at: span.lowerBound) }
        try rules.checkAuxiliaryDataSet(at: spans[3].lowerBound)

        var block = try Transaction.decoder().decode(Block.self, from: data)

        block.header.originalCBOR = bytes.subdata(in: spans[0])
        for (index, span) in bodySpans.enumerated() where index < block.transactionBodies.count {
            try block.transactionBodies[index].keepBytes(bytes.subdata(in: span))
        }
        for (index, span) in witnessSpans.enumerated() where index < block.transactionWitnessSets.count {
            try block.transactionWitnessSets[index].keepBytes(bytes.subdata(in: span))
        }
        for (key, value) in auxiliaryEntries {
            guard let index = try scanner.unsignedInteger(at: key.lowerBound),
                let transactionIndex = TransactionIndex(exactly: index),
                block.auxiliaryDataSet[transactionIndex] != nil
            else { continue }
            try block.auxiliaryDataSet[transactionIndex]?.keepBytes(bytes.subdata(in: value))
        }
        block.originalCBOR = bytes
        return block
    }

    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// The bytes this block was decoded from while it is unchanged; otherwise
    /// a fresh encoding that keeps the written bytes of every part that is
    /// unchanged.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        if let originalCBOR { return originalCBOR }
        let parts = try encodedParts()
        return CBORItemScanner.definiteHeader(major: 4, count: parts.count + 1)
            + (try header.toCBORData()) + parts.reduce(Data(), +)
    }

    /// The block's hash: the hash of its header as written, which the next
    /// block names as its predecessor.
    public func hash() -> Data {
        header.hash()
    }

    /// The hash of the block body, which the header commits to as its
    /// `block_body_hash`: Blake2b-256 over the Blake2b-256 hashes of the
    /// transaction bodies, the witness sets, the auxiliary data and — from
    /// Alonzo — the invalid transactions, each taken over its bytes as written.
    public func bodyHash() throws -> BlockBodyHash {
        let hashes = try encodedParts().map { try Self.blake2b256($0) }
        return BlockBodyHash(payload: try Self.blake2b256(hashes.reduce(Data(), +)))
    }

    private static func blake2b256(_ data: Data) throws -> Data {
        try Hash().blake2b(data: data, digestSize: BLOCK_BODY_HASH_SIZE, encoder: RawEncoder.self)
    }

    /// The bytes of every element after the header: as written while this
    /// block is unchanged, otherwise freshly encoded from parts that keep
    /// their own bytes.
    private func encodedParts() throws -> [Data] {
        if let originalCBOR {
            let scanner = CBORItemScanner(originalCBOR)
            return try scanner.elements(ofArrayAt: 0).dropFirst().map { originalCBOR.subdata(in: $0) }
        }
        guard !isPreAlonzo || invalidTransactions.isEmpty else {
            throw CardanoCoreError.valueError("A Shelley to Mary block has no invalid transactions")
        }
        var bodies = CBORItemScanner.definiteHeader(major: 4, count: transactionBodies.count)
        for body in transactionBodies {
            bodies.append(try body.toCBORData())
        }
        var witnessSets = CBORItemScanner.definiteHeader(major: 4, count: transactionWitnessSets.count)
        for witnessSet in transactionWitnessSets {
            witnessSets.append(try witnessSet.toCBORData())
        }
        var auxiliaryData = CBORItemScanner.definiteHeader(major: 5, count: auxiliaryDataSet.count)
        let encoder = CBOREncoder()
        for (index, entry) in auxiliaryDataSet {
            auxiliaryData.append(try encoder.encode(Primitive.uint(UInt64(index))))
            auxiliaryData.append(try entry.toCBORData())
        }
        guard !isPreAlonzo else { return [bodies, witnessSets, auxiliaryData] }
        let invalid = try encoder.encode(Primitive.list(invalidTransactions.map { .uint(UInt64($0)) }))
        return [bodies, witnessSets, auxiliaryData, invalid]
    }

    // MARK: - CBORSerializable

    /// Witness sets and auxiliary data are read as written; the header and
    /// bodies in the usual form.
    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let l): elements = l
        case .indefiniteList(let l): elements = Array(l)
        default:
            throw CardanoCoreError.deserializeError("Invalid Block primitive: expected list")
        }

        guard elements.count == 4 || elements.count == 5 else {
            throw CardanoCoreError.deserializeError(
                "Block requires 4 or 5 elements, got \(elements.count)"
            )
        }
        self.isPreAlonzo = elements.count == 4

        // 0: header
        self.header = try Header(from: elements[0].normalized())

        // 1: transaction_bodies : [* transaction_body]
        let txBodyPrimitives: [Primitive]
        switch elements[1] {
        case .list(let l): txBodyPrimitives = l
        case .indefiniteList(let l): txBodyPrimitives = Array(l)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block transaction_bodies: expected list")
        }
        self.transactionBodies = try txBodyPrimitives.map { try TransactionBody(from: $0.normalized()) }

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
        case .orderedDict(let dict), .indefiniteDictionary(let dict):
            for (key, value) in dict {
                let index: TransactionIndex
                switch key {
                case .uint(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
                case .int(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
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
                case .uint(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
                case .int(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
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

        // 4: invalid_transactions : [* transaction_index], from Alonzo
        let invalidTxPrimitives: [Primitive]
        switch isPreAlonzo ? .list([]) : elements[4] {
        case .list(let l): invalidTxPrimitives = l
        case .indefiniteList(let l): invalidTxPrimitives = Array(l)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid Block invalid_transactions: expected list")
        }
        self.invalidTransactions = try invalidTxPrimitives.map { element in
            switch element {
            case .uint(let val) where TransactionIndex(exactly: val) != nil: return TransactionIndex(val)
            case .int(let val) where TransactionIndex(exactly: val) != nil: return TransactionIndex(val)
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

        guard !isPreAlonzo || invalidTxs.isEmpty else {
            throw CardanoCoreError.valueError("A Shelley to Mary block has no invalid transactions")
        }
        return .list([
            try header.toPrimitive(),
            .list(txBodies),
            .list(txWitnesses),
            .orderedDict(auxDataDict),
        ] + (isPreAlonzo ? [] : [.list(invalidTxs)]))
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
                case .uint(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
                case .int(let val) where TransactionIndex(exactly: val) != nil: index = TransactionIndex(val)
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

    /// Hashes what `==` compares, leaving out the bytes it was read from.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(header)
        hasher.combine(transactionBodies)
    }
}
