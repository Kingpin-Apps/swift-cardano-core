import Foundation

// MARK: - ByronTransaction

/// A Byron era transaction, as defined in the Byron CDDL:
/// ```
/// tx = [[+ txin], [+ txout], attributes]
/// ```
///
/// A decoded transaction keeps the bytes it was read from. Its ``id`` is the
/// Blake2b-256 hash of those bytes, so it is the transaction id on chain.
public struct ByronTransaction: Sendable, Equatable, Hashable {
    /// The outputs this transaction spends.
    public var inputs: [ByronTransactionInput] { didSet { _original.data = nil } }
    /// The outputs this transaction creates.
    public var outputs: [ByronTransactionOutput] { didSet { _original.data = nil } }
    /// Transaction attributes; empty on mainnet.
    public var attributes: ByronAttributes { didSet { _original.data = nil } }

    var _original = ByronOriginalBytes()

    /// The exact bytes this transaction was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? {
        get { _original.data }
        set { _original.data = newValue }
    }

    public init(
        inputs: [ByronTransactionInput],
        outputs: [ByronTransactionOutput],
        attributes: ByronAttributes = .empty
    ) {
        self.inputs = inputs
        self.outputs = outputs
        self.attributes = attributes
    }

    /// The transaction id: Blake2b-256 of the transaction's bytes.
    public var id: TransactionId {
        TransactionId(payload: hash())
    }

    public func hash() -> Data {
        ByronHash.blake2b256(try! toCBORData())
    }

    /// Decodes a transaction, keeping the bytes it was read from.
    public static func fromCBOR(data: Data) throws -> ByronTransaction {
        try decode(try ByronCBORItem(root: data, "Byron transaction"))
    }

    /// The bytes this transaction was decoded from while it is unchanged;
    /// otherwise a fresh encoding, with inputs and outputs as indefinite-length
    /// arrays as the Byron node writes them.
    public func toCBORData() throws -> Data {
        try originalCBOR ?? freshCBOR()
    }

    func freshCBOR() throws -> Data {
        var writer = ByronCBORWriter()
        writer.array(3)
        writer.indefiniteArray(inputs) { $1.write(to: &$0) }
        writer.indefiniteArray(outputs) { $1.write(to: &$0) }
        writer.raw(try attributes.toCBORData())
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronTransaction {
        let elements = try item.array("tx", count: 3)
        let inputs = try elements[0].array("tx inputs").map(ByronTransactionInput.decode)
        let outputs = try elements[1].array("tx outputs").map(ByronTransactionOutput.decode)
        guard !inputs.isEmpty, !outputs.isEmpty else {
            throw CardanoCoreError.deserializeError("tx: inputs and outputs must not be empty")
        }
        var transaction = ByronTransaction(
            inputs: inputs,
            outputs: outputs,
            attributes: try ByronAttributes.decode(elements[2], "tx attributes")
        )
        transaction.originalCBOR = item.bytes
        return transaction
    }
}

// MARK: - ByronTransactionInput

/// A Byron transaction input.
///
/// ```
/// txin = [0, #6.24(bytes .cbor ([txid, u32]))] / [u8 .ne 0, encoded-cbor]
/// ```
public enum ByronTransactionInput: Sendable, Equatable, Hashable {
    /// `[0, #6.24([txid, index])]` — an output of an earlier transaction.
    case utxo(transactionId: TransactionId, index: UInt32)
    /// `[tag, payload]` for a tag the ledger does not define; `payload` is the
    /// CBOR of the second element as written.
    case unknown(tag: UInt8, payload: Data)

    static func decode(_ item: ByronCBORItem) throws -> ByronTransactionInput {
        let elements = try item.array("txin", count: 2)
        let tag = try elements[0].uint("txin tag", as: UInt8.self)
        guard tag == 0 else {
            return .unknown(tag: tag, payload: elements[1].bytes)
        }
        let reference = try elements[1].embedded("txin").array("txin [txid, index]", count: 2)
        return .utxo(
            transactionId: TransactionId(
                payload: try reference[0].byteString("txin txid", count: 32)),
            index: try reference[1].uint("txin index", as: UInt32.self)
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(2)
        switch self {
        case .utxo(let transactionId, let index):
            writer.uint(0 as UInt8)
            writer.embedded(ByronCBORWriter.encode {
                $0.array(2)
                $0.bytes(transactionId.payload)
                $0.uint(index)
            })
        case .unknown(let tag, let payload):
            writer.uint(tag)
            writer.raw(payload)
        }
    }
}

// MARK: - ByronTransactionOutput

/// A Byron transaction output: `txout = [address, u64]`.
public struct ByronTransactionOutput: Sendable, Equatable, Hashable {
    /// The Byron address the output pays to.
    public var address: ByronAddress
    /// The amount, in lovelace.
    public var amount: UInt64

    public init(address: ByronAddress, amount: UInt64) {
        self.address = address
        self.amount = amount
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronTransactionOutput {
        let elements = try item.array("txout", count: 2)
        return ByronTransactionOutput(
            address: try ByronAddress(from: .bytes(elements[0].bytes)),
            amount: try elements[1].uint("txout amount")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(2)
        writer.raw(address.toBytes())
        writer.uint(amount)
    }
}

// MARK: - ByronTransactionWitness

/// A Byron transaction witness.
///
/// ```
/// twit = [0, #6.24(bytes .cbor ([pubkey, signature]))]
///      / [1, #6.24(bytes .cbor ([[u16, bytes], [u16, bytes]]))]
///      / [2, #6.24(bytes .cbor ([pubkey, signature]))]
///      / [u8 .gt 2, encoded-cbor]
/// ```
public enum ByronTransactionWitness: Sendable, Equatable, Hashable {
    /// `[0, …]` — a signature by the key the spent address commits to.
    case publicKey(publicKey: Data, signature: Data)
    /// `[1, …]` — a validator and redeemer script pair.
    case script(validator: ByronScript, redeemer: ByronScript)
    /// `[2, …]` — a signature by an ADA voucher redemption key.
    case redeem(publicKey: Data, signature: Data)
    /// `[tag, payload]` for a tag the ledger does not define; `payload` is the
    /// CBOR of the second element as written.
    case unknown(tag: UInt8, payload: Data)

    static func decode(_ item: ByronCBORItem) throws -> ByronTransactionWitness {
        let elements = try item.array("twit", count: 2)
        let tag = try elements[0].uint("twit tag", as: UInt8.self)
        switch tag {
        case 0, 2:
            let pair = try elements[1].embedded("twit").array("twit [pubkey, signature]", count: 2)
            let publicKey = try pair[0].byteString("twit pubkey")
            let signature = try pair[1].byteString("twit signature")
            return tag == 0
                ? .publicKey(publicKey: publicKey, signature: signature)
                : .redeem(publicKey: publicKey, signature: signature)
        case 1:
            let pair = try elements[1].embedded("twit").array("twit [validator, redeemer]", count: 2)
            return .script(
                validator: try ByronScript.decode(pair[0]),
                redeemer: try ByronScript.decode(pair[1])
            )
        default:
            return .unknown(tag: tag, payload: elements[1].bytes)
        }
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(2)
        switch self {
        case .publicKey(let publicKey, let signature), .redeem(let publicKey, let signature):
            writer.uint(tag)
            writer.embedded(ByronCBORWriter.encode {
                $0.array(2)
                $0.bytes(publicKey)
                $0.bytes(signature)
            })
        case .script(let validator, let redeemer):
            writer.uint(1 as UInt8)
            writer.embedded(ByronCBORWriter.encode {
                $0.array(2)
                validator.write(to: &$0)
                redeemer.write(to: &$0)
            })
        case .unknown(let tag, let payload):
            writer.uint(tag)
            writer.raw(payload)
        }
    }

    private var tag: UInt8 {
        switch self {
        case .publicKey: return 0
        case .script: return 1
        case .redeem: return 2
        case .unknown(let tag, _): return tag
        }
    }
}

/// A versioned Byron script: `[u16, bytes]`.
public struct ByronScript: Sendable, Equatable, Hashable {
    public var version: UInt16
    public var script: Data

    public init(version: UInt16, script: Data) {
        self.version = version
        self.script = script
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronScript {
        let elements = try item.array("script", count: 2)
        return ByronScript(
            version: try elements[0].uint("script version", as: UInt16.self),
            script: try elements[1].byteString("script")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(2)
        writer.uint(version)
        writer.bytes(script)
    }
}

// MARK: - ByronTransactionAux

/// A transaction with its witnesses, as one entry of a block's transaction
/// payload: `[tx, [* twit]]`.
public struct ByronTransactionAux: Sendable, Equatable, Hashable {
    public var transaction: ByronTransaction { didSet { _original.data = nil } }
    /// One witness per input, in input order.
    public var witnesses: [ByronTransactionWitness] { didSet { _original.data = nil } }

    var _original = ByronOriginalBytes()

    /// The exact bytes this entry was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? {
        get { _original.data }
        set { _original.data = newValue }
    }

    public init(transaction: ByronTransaction, witnesses: [ByronTransactionWitness]) {
        self.transaction = transaction
        self.witnesses = witnesses
    }

    /// The id of the transaction.
    public var id: TransactionId { transaction.id }

    /// Decodes an entry, keeping its bytes and those of its transaction.
    public static func fromCBOR(data: Data) throws -> ByronTransactionAux {
        try decode(try ByronCBORItem(root: data, "Byron transaction aux"))
    }

    /// The bytes this entry was decoded from while it is unchanged; otherwise
    /// a fresh encoding that keeps the transaction's bytes if it is unchanged.
    /// Witnesses are written as a definite-length array, as the node does.
    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.array(2)
        writer.raw(try transaction.toCBORData())
        writer.definiteArray(witnesses) { $1.write(to: &$0) }
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronTransactionAux {
        let elements = try item.array("[tx, [* twit]]", count: 2)
        var aux = ByronTransactionAux(
            transaction: try ByronTransaction.decode(elements[0]),
            witnesses: try elements[1].array("twits").map(ByronTransactionWitness.decode)
        )
        aux.originalCBOR = item.bytes
        return aux
    }
}
