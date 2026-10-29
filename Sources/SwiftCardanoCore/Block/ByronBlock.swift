import Foundation
import OrderedCollections
import CBORCodable

/// A Byron era block — either an Epoch Boundary Block or a regular block.
///
/// Byron uses a completely different CDDL from Shelley+:
/// ```
/// block     = [0, ebblock] / [1, mainblock]
/// ebblock   = [header : ebbhead,   body : [* stakeholderid], extra : [attributes]]
/// mainblock = [header : blockhead, body : blockbody,         extra : [attributes]]
/// ```
///
/// A decoded block keeps the bytes it was read from, as do its header, its
/// body and each of its transactions, so it re-encodes to exactly those
/// bytes while unchanged, and a change to one part re-encodes that part
/// alone. The block hash — see ``hash()`` — is Blake2b-256 of
/// `[discriminant, header]`.
///
/// A block can also be decoded from the NtN header-only form
/// `[[discriminant, blockSize], #6.24(head)]`; it then has a header and no
/// body.
public enum ByronBlock: Sendable {
    case ebb(EBB)
    case bft(BFT)

    // MARK: - EBB

    /// Epoch Boundary Block — marks transitions between Byron epochs.
    /// EBBs carry no transactions; their body lists stakeholder ids.
    public struct EBB: Sendable, Equatable, Hashable {
        public var header: ByronBlockHeader.EBBHead { didSet { _original.data = nil } }
        /// The stakeholder ids of `[* stakeholderid]` (Blake2b-224 hashes);
        /// `nil` when only the header was decoded.
        public var body: [Data]? { didSet { _original.data = nil } }
        /// The block's `extra = [attributes]`; empty when only the header
        /// was decoded.
        public var extra: [ByronAttributes] { didSet { _original.data = nil } }
        /// The block size from the NtN header framing, when the block was
        /// decoded from it.
        public var blockSizeHint: UInt32? { didSet { _original.data = nil } }

        var _original = ByronOriginalBytes()

        /// The exact bytes this block was decoded from, while it is unchanged.
        public internal(set) var originalCBOR: Data? {
            get { _original.data }
            set { _original.data = newValue }
        }

        public init(
            header: ByronBlockHeader.EBBHead,
            body: [Data]?,
            extra: [ByronAttributes] = [.empty],
            blockSizeHint: UInt32? = nil
        ) {
            self.header = header
            self.body = body
            self.extra = extra
            self.blockSizeHint = blockSizeHint
        }

        /// The block hash: the hash of its header.
        public func hash() throws -> Data { try header.hash() }

        /// Network protocol magic.
        public var protocolMagic: UInt32 { header.protocolMagic }
        /// Hash of the previous block, or `nil` if it is empty.
        public var prevHash: Data? { header.prevBlock.isEmpty ? nil : header.prevBlock }
        /// Epoch number.
        public var epoch: UInt64 { header.epoch }
        /// Chain difficulty, equal to the block height at this point.
        public var difficulty: UInt64 { header.difficulty }

        func freshCBOR() throws -> Data {
            var writer = ByronCBORWriter()
            guard let body else {
                ByronBlock.writeHeaderOnly(
                    discriminant: 0, blockSizeHint: blockSizeHint,
                    headerCBOR: try header.toCBORData(), to: &writer)
                return writer.data
            }
            writer.array(2)
            writer.uint(0 as UInt8)
            writer.array(3)
            writer.raw(try header.toCBORData())
            writer.indefiniteArray(body) { $0.bytes($1) }
            try ByronBlock.writeExtra(extra, to: &writer)
            return writer.data
        }
    }

    // MARK: - BFT

    /// A regular Byron block: a header signed by a BFT delegate, and a body
    /// of transactions, SSC, delegation and update payloads.
    public struct BFT: Sendable, Equatable, Hashable {
        public var header: ByronBlockHeader.BFTHead { didSet { _original.data = nil } }
        /// The block body; `nil` when only the header was decoded.
        public var body: ByronBlockBody? { didSet { _original.data = nil } }
        /// The block's `extra = [attributes]`; empty when only the header
        /// was decoded.
        public var extra: [ByronAttributes] { didSet { _original.data = nil } }
        /// The block size from the NtN header framing, when the block was
        /// decoded from it.
        public var blockSizeHint: UInt32? { didSet { _original.data = nil } }

        var _original = ByronOriginalBytes()

        /// The exact bytes this block was decoded from, while it is unchanged.
        public internal(set) var originalCBOR: Data? {
            get { _original.data }
            set { _original.data = newValue }
        }

        public init(
            header: ByronBlockHeader.BFTHead,
            body: ByronBlockBody?,
            extra: [ByronAttributes] = [.empty],
            blockSizeHint: UInt32? = nil
        ) {
            self.header = header
            self.body = body
            self.extra = extra
            self.blockSizeHint = blockSizeHint
        }

        /// The block hash: the hash of its header.
        public func hash() throws -> Data { try header.hash() }

        /// Network protocol magic.
        public var protocolMagic: UInt32 { header.protocolMagic }
        /// Hash of the previous block, or `nil` if it is empty.
        public var prevHash: Data? { header.prevBlock.isEmpty ? nil : header.prevBlock }
        /// Epoch number from the block's `slotId`.
        public var epoch: UInt64 { header.slotId.epoch }
        /// Slot within the epoch from the block's `slotId`.
        public var slotWithinEpoch: UInt64 { header.slotId.slot }
        /// The absolute slot, given the number of slots in a Byron epoch.
        public func absoluteSlot(epochLength: UInt64 = ByronBlockHeader.mainnetEpochLength) -> UInt64 {
            header.absoluteSlot(epochLength: epochLength)
        }
        /// Block issuer (delegate) verification key, normally a 64-byte
        /// extended Ed25519 key.
        public var issuerVKey: Data { header.issuerKey }
        /// Chain difficulty, equal to the block height at this point.
        public var difficulty: UInt64 { header.difficulty }
        /// Byron protocol version from `extraData`.
        public var protocolVersion: ByronProtocolVersion { header.blockVersion }
        /// Byron software version from `extraData`.
        public var softwareVersion: ByronSoftwareVersion { header.softwareVersion }
        /// The transactions with their witnesses; empty when only the header
        /// was decoded.
        public var transactions: [ByronTransactionAux] { body?.transactions ?? [] }
        /// Number of transactions in the block body.
        /// Zero when only the header was decoded.
        public var transactionCount: Int { transactions.count }

        func freshCBOR() throws -> Data {
            var writer = ByronCBORWriter()
            guard let body else {
                ByronBlock.writeHeaderOnly(
                    discriminant: 1, blockSizeHint: blockSizeHint,
                    headerCBOR: try header.toCBORData(), to: &writer)
                return writer.data
            }
            writer.array(2)
            writer.uint(1 as UInt8)
            writer.array(3)
            writer.raw(try header.toCBORData())
            writer.raw(try body.toCBORData())
            try ByronBlock.writeExtra(extra, to: &writer)
            return writer.data
        }
    }

    // MARK: - Supporting types

    /// Byron protocol version from the block's `extraData`.
    public typealias ByronProtocolVersion = ByronBlockHeader.BlockVersion

    /// Byron software version from the block's `extraData`.
    public typealias ByronSoftwareVersion = ByronBlockHeader.SoftwareVersion

    // MARK: - Convenience accessors

    /// The block header regardless of variant.
    public var header: ByronBlockHeader {
        switch self {
        case .ebb(let e): return .ebb(e.header)
        case .bft(let b): return .bft(b.header)
        }
    }

    /// The block hash: Blake2b-256 of `[discriminant, header]`.
    public func hash() throws -> Data {
        switch self {
        case .ebb(let e): return try e.hash()
        case .bft(let b): return try b.hash()
        }
    }

    /// The previous block hash regardless of variant.
    public var prevHash: Data? {
        switch self {
        case .ebb(let e): return e.prevHash
        case .bft(let b): return b.prevHash
        }
    }

    /// Chain difficulty (block height) regardless of variant.
    public var difficulty: UInt64 {
        switch self {
        case .ebb(let e): return e.difficulty
        case .bft(let b): return b.difficulty
        }
    }

    /// Whether only the header was decoded, from the NtN header-only form.
    public var isHeaderOnly: Bool {
        switch self {
        case .ebb(let e): return e.body == nil
        case .bft(let b): return b.body == nil
        }
    }

    /// The exact bytes this block was decoded from, while it is unchanged.
    public var originalCBOR: Data? {
        switch self {
        case .ebb(let e): return e.originalCBOR
        case .bft(let b): return b.originalCBOR
        }
    }

    // MARK: - Decoding

    /// Decodes a block, keeping the bytes of it and of its parts.
    ///
    /// `data` is either the full block `[discriminant, block_content]` or the
    /// NtN header-only form `[[discriminant, blockSize], #6.24(head)]`.
    public static func fromCBOR(data: Data) throws -> ByronBlock {
        let item = try ByronCBORItem(root: data, "ByronBlock")
        let elements = try item.array("ByronBlock", count: 2)
        switch try elements[0].header().major {
        case 0:
            return try decodeFull(
                discriminant: try elements[0].uint("ByronBlock discriminant"),
                content: elements[1], bytes: item.bytes)
        case 4:
            return try decodeHeaderOnly(elements, bytes: item.bytes)
        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlock: unexpected top-level element type (expected uint or list)")
        }
    }

    /// `[0, ebblock] / [1, mainblock]`
    private static func decodeFull(
        discriminant: UInt64, content: ByronCBORItem, bytes: Data
    ) throws -> ByronBlock {
        let elements = try content.array("ByronBlock content", count: 3)
        let extra = try elements[2].array("ByronBlock extra").map {
            try ByronAttributes.decode($0, "ByronBlock extra")
        }
        switch discriminant {
        case 0:
            var ebb = EBB(
                header: try ByronBlockHeader.EBBHead.decode(elements[0]),
                body: try elements[1].array("ebblock body").map {
                    try $0.byteString("ebblock stakeholder id", count: 28)
                },
                extra: extra
            )
            ebb.originalCBOR = bytes
            return .ebb(ebb)
        case 1:
            var bft = BFT(
                header: try ByronBlockHeader.BFTHead.decode(elements[0]),
                body: try ByronBlockBody.decode(elements[1]),
                extra: extra
            )
            bft.originalCBOR = bytes
            return .bft(bft)
        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlock: unknown discriminant \(discriminant)")
        }
    }

    /// `[[discriminant, blockSize], #6.24(head)]`, as NtN ChainSync sends
    /// Byron headers.
    static func decodeHeaderOnly(_ elements: [ByronCBORItem], bytes: Data) throws -> ByronBlock {
        let framing = try elements[0].array("ByronBlock NtN framing", count: 2)
        let discriminant = try framing[0].uint("ByronBlock NtN discriminant")
        let sizeHint = try framing[1].uint("ByronBlock NtN block size", as: UInt32.self)
        let header = try ByronBlockHeader.decode(
            try elements[1].embedded("ByronBlock NtN header"), discriminant: discriminant)
        switch header {
        case .ebb(let head):
            var ebb = EBB(header: head, body: nil, extra: [], blockSizeHint: sizeHint)
            ebb.originalCBOR = bytes
            return .ebb(ebb)
        case .bft(let head):
            var bft = BFT(header: head, body: nil, extra: [], blockSizeHint: sizeHint)
            bft.originalCBOR = bytes
            return .bft(bft)
        }
    }

    // MARK: - Encoding

    /// The bytes this block was decoded from while it is unchanged;
    /// otherwise a fresh encoding that keeps the bytes of each unchanged part.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        switch self {
        case .ebb(let e): return try e.originalCBOR ?? e.freshCBOR()
        case .bft(let b): return try b.originalCBOR ?? b.freshCBOR()
        }
    }

    fileprivate static func writeHeaderOnly(
        discriminant: UInt8, blockSizeHint: UInt32?, headerCBOR: Data,
        to writer: inout ByronCBORWriter
    ) {
        writer.array(2)
        writer.array(2)
        writer.uint(discriminant)
        writer.uint(blockSizeHint ?? 0)
        writer.embedded(headerCBOR)
    }

    fileprivate static func writeExtra(
        _ extra: [ByronAttributes], to writer: inout ByronCBORWriter
    ) throws {
        writer.array(extra.count)
        for attributes in extra {
            writer.raw(try attributes.toCBORData())
        }
    }
}

// MARK: - Equatable & Hashable

extension ByronBlock: Equatable, Hashable {}

// MARK: - Serializable

extension ByronBlock: Serializable {

    // MARK: CBORSerializable

    /// Decodes from the full block or NtN header-only form.
    ///
    /// A primitive does not record how its items were written, so prefer
    /// ``fromCBOR(data:)`` where the block hash or transaction ids matter.
    public init(from primitive: Primitive) throws {
        self = try Self.fromCBOR(data: CBORSerialization.data(from: primitive.toCBOR()))
    }

    /// The bytes ``toCBORData(deterministic:)`` gives, kept as they are, so
    /// that encoding this alone or inside another value writes exactly them.
    public func toPrimitive() throws -> Primitive {
        .cborSimpleValue(.encoded(try toCBORData()))
    }

    // MARK: JSONSerializable

    /// Decodes from the dictionary ``toDict()`` writes, using its `cbor` field;
    /// the other fields are a summary for reading.
    public static func fromDict(_ primitive: Primitive) throws -> ByronBlock {
        guard case .orderedDict(let dict) = primitive,
            case .string(let hex) = dict[.string("cbor")] ?? .null,
            let data = Data(hexString: hex)
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock.fromDict: expected a dict with a 'cbor' hex string")
        }
        let block = try fromCBOR(data: data)
        if case .string(let type_) = dict[.string("type")] ?? .null,
            type_ != (block.header.discriminant == 0 ? "ebb" : "bft")
        {
            throw CardanoCoreError.deserializeError(
                "ByronBlock.fromDict: 'type' \(type_) does not match the block")
        }
        return block
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("hash")] = .string(try hash().toHex)
        dict[.string("protocolMagic")] = .uint(UInt64(header.protocolMagic))
        dict[.string("prevHash")] = prevHash.map { .string($0.toHex) } ?? .null
        switch self {
        case .ebb(let ebb):
            dict[.string("type")] = .string("ebb")
            dict[.string("epoch")] = .uint(ebb.epoch)
            dict[.string("difficulty")] = .uint(ebb.difficulty)
        case .bft(let bft):
            dict[.string("type")] = .string("bft")
            dict[.string("epoch")] = .uint(bft.epoch)
            dict[.string("slotWithinEpoch")] = .uint(bft.slotWithinEpoch)
            dict[.string("issuerVKey")] = .string(bft.issuerVKey.toHex)
            dict[.string("difficulty")] = .uint(bft.difficulty)

            var pvDict = OrderedDictionary<Primitive, Primitive>()
            pvDict[.string("major")] = .uint(UInt64(bft.protocolVersion.major))
            pvDict[.string("minor")] = .uint(UInt64(bft.protocolVersion.minor))
            pvDict[.string("alt")] = .uint(UInt64(bft.protocolVersion.alt))
            dict[.string("protocolVersion")] = .orderedDict(pvDict)

            var svDict = OrderedDictionary<Primitive, Primitive>()
            svDict[.string("appName")] = .string(bft.softwareVersion.appName)
            svDict[.string("number")] = .uint(UInt64(bft.softwareVersion.number))
            dict[.string("softwareVersion")] = .orderedDict(svDict)

            dict[.string("transactionCount")] = .uint(UInt64(bft.transactionCount))
            dict[.string("transactionIds")] = .list(
                try bft.transactions.map { .string(try $0.id.payload.toHex) })
        }
        dict[.string("cbor")] = .string(try toCBORData().toHex)
        return .orderedDict(dict)
    }
}
