import Foundation
import OrderedCollections
import CBORCodable

/// A Cardano block from any era, decoded from the NtN/NtC wire format.
///
/// On the network, blocks arrive era-tagged:
/// ```
/// [era_id : uint, #6.24(block_cbor_bytes)]
/// ```
/// where `era_id` maps to:
/// - 0: Byron
/// - 1: Shelley
/// - 2: Allegra
/// - 3: Mary
/// - 4: Alonzo
/// - 5: Babbage
/// - 6: Conway
///
/// Shelley through Conway share the same `Block` structure — 4 elements to
/// Mary, 5 from Alonzo — and the header body's layout: 15 flat elements to
/// Alonzo, 10 with nested fields from Babbage (see ``HeaderBody``).
/// Byron uses a completely different structure and is represented by `ByronBlock`.
///
/// ## Byron wire format variants
///
/// **NtC (full block)** — after stripping the outer `[era_id, #6.24(...)]` wrapper,
/// `data` is `[discriminant, block_content]` where `elements[0]` is a uint:
/// ```
/// [0, ebblock]    ; ebblock  = [ebbhead,   ebbbody,    ebbatts]
/// [1, mainblock]  ; mainblock = [blockhead, blockbody, blockextra]
/// ```
/// Both EBB and BFT heads are 5-element arrays; the discriminant identifies which.
///
/// **NtN (header only)** — `data` is a 2-element array where `elements[0]` is a list:
/// ```
/// [[discriminant, blockSize], #6.24(head_bytes)]
///   discriminant 0 → EBB, 1 → BFT; blockSize is the size of the whole block in bytes
/// ```
public enum EraBlock: Sendable {
    case byron(ByronBlock)
    case shelley(Block)
    case allegra(Block)
    case mary(Block)
    case alonzo(Block)
    case babbage(Block)
    case conway(Block)

    /// The numeric era identifier (0 = Byron … 6 = Conway).
    public var eraId: UInt64 {
        switch self {
        case .byron: return 0
        case .shelley: return 1
        case .allegra: return 2
        case .mary: return 3
        case .alonzo: return 4
        case .babbage: return 5
        case .conway: return 6
        }
    }

    /// The Shelley+ block body, or `nil` for Byron.
    public var block: Block? {
        switch self {
        case .byron: return nil
        case .shelley(let b),
            .allegra(let b),
            .mary(let b),
            .alonzo(let b),
            .babbage(let b),
            .conway(let b):
            return b
        }
    }

    // MARK: - Network CBOR decoding

    /// Decode from the full NtN/NtC outer wrapper: `[era_id, #6.24(block_cbor)]`.
    public static func fromNetworkCBOR(data: Data) throws -> EraBlock {
        let primitive = try Primitive.from(cbor: CBORDecoder.ledger().decode(CBOR.self, from: data))

        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlock: expected [era_id, #6.24(block)] 2-element array"
            )
        }

        let eraId = try elements[0].integer("EraBlock era_id", as: UInt64.self)

        let blockBytes = try unwrapTag24(elements[1])
        return try fromBlockCBOR(data: blockBytes, era: eraId)
    }

    /// Decode from raw block CBOR bytes for a known era.
    ///
    /// Use this when the era is already known (e.g. from `RawBlock.era`) and
    /// the outer `[era_id, #6.24(…)]` wrapper has already been stripped.
    ///
    /// For Byron (era 0), `data` may be either:
    /// - NtC: `[discriminant, block_content]` where `elements[0]` is a uint
    /// - NtN: `[[discriminant, epochOrSlot], #6.24(head)]` where `elements[0]` is a list
    public static func fromBlockCBOR(data: Data, era: UInt64) throws -> EraBlock {
        switch era {
        case 0:
            return .byron(try parseByronBlock(data: data))
        case 1:
            return .shelley(try Block.fromCBOR(data: data, era: .shelley))
        case 2:
            return .allegra(try Block.fromCBOR(data: data, era: .allegra))
        case 3:
            return .mary(try Block.fromCBOR(data: data, era: .mary))
        case 4:
            return .alonzo(try Block.fromCBOR(data: data, era: .alonzo))
        case 5:
            return .babbage(try Block.fromCBOR(data: data, era: .babbage))
        case 6:
            return .conway(try Block.fromCBOR(data: data, era: .conway))
        default:
            throw CardanoCoreError.deserializeError("EraBlock: unknown era id \(era)")
        }
    }

    // MARK: - Byron parsing

    /// Parse a `ByronBlock` from raw bytes, keeping them.
    ///
    /// Detects the wire format by the type of `elements[0]`:
    /// - **uint** → NtC: `[discriminant, block_content]` (both EBB and BFT are 2-element)
    /// - **list** → NtN: `[[discriminant, blockSize], #6.24(head)]`
    private static func parseByronBlock(data: Data) throws -> ByronBlock {
        try ByronBlock.fromCBOR(data: data)
    }

    // MARK: - Shared helpers

    /// Unwrap a `#6.24(bytes)` CBOR tag and return the inner bytes,
    /// or pass through a raw byte string directly.
    private static func unwrapTag24(_ primitive: Primitive) throws -> Data {
        switch primitive {
        case .cborTag(let tag):
            guard tag.tag == 24 else {
                throw CardanoCoreError.deserializeError(
                    "EraBlock: expected tag 24 (embedded CBOR), got tag \(tag.tag)"
                )
            }
            guard case .bytes(let bytes) = tag.value else {
                throw CardanoCoreError.deserializeError(
                    "EraBlock: tag-24 value must be bytes"
                )
            }
            return bytes
        case .bytes(let bytes):
            return bytes
        default:
            throw CardanoCoreError.deserializeError(
                "EraBlock: expected tag-24 or bytes for block payload"
            )
        }
    }
}

// MARK: - Equatable & Hashable

extension EraBlock: Equatable, Hashable {}

// MARK: - Serializable

extension EraBlock: Serializable {

    // MARK: CBORSerializable

    /// Decode from the full NtN/NtC outer wrapper: `[era_id, #6.24(block_cbor)]`.
    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlock: expected [era_id, #6.24(block)] 2-element array"
            )
        }
        let eraId = try elements[0].integer("EraBlock era_id", as: UInt64.self)
        let blockBytes = try Self.unwrapTag24(elements[1])
        self = try Self.fromBlockCBOR(data: blockBytes, era: eraId)
    }

    /// Encode to `[era_id, #6.24(block_cbor)]`.
    public func toPrimitive() throws -> Primitive {
        let innerBytes: Data
        switch self {
        case .byron(let b): innerBytes = try b.toCBORData()
        case .shelley(let b),
            .allegra(let b),
            .mary(let b),
            .alonzo(let b),
            .babbage(let b),
            .conway(let b):
            innerBytes = try b.toCBORData()
        }
        return .list([
            .uint(UInt64(eraId)),
            .cborTag(CBORTag(tag: 24, value: .bytes(innerBytes))),
        ])
    }

    // MARK: JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> EraBlock {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("EraBlock.fromDict: expected dict")
        }
        guard let eraP = dict[.string("era")] else {
            throw CardanoCoreError.deserializeError("EraBlock.fromDict: missing 'era' field")
        }
        let eraId = try eraP.integer("EraBlock era_id", as: UInt64.self)
        guard let blockP = dict[.string("block")] else {
            throw CardanoCoreError.deserializeError("EraBlock.fromDict: missing 'block' field")
        }
        switch eraId {
        case 0: return .byron(try ByronBlock.fromDict(blockP))
        case 1: return .shelley(try Block.fromDict(blockP))
        case 2: return .allegra(try Block.fromDict(blockP))
        case 3: return .mary(try Block.fromDict(blockP))
        case 4: return .alonzo(try Block.fromDict(blockP))
        case 5: return .babbage(try Block.fromDict(blockP))
        case 6: return .conway(try Block.fromDict(blockP))
        default:
            throw CardanoCoreError.deserializeError("EraBlock.fromDict: unknown era \(eraId)")
        }
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("era")] = .uint(UInt64(eraId))
        let blockP: Primitive
        switch self {
        case .byron(let b): blockP = try b.toDict()
        case .shelley(let b),
            .allegra(let b),
            .mary(let b),
            .alonzo(let b),
            .babbage(let b),
            .conway(let b):
            blockP = try b.toDict()
        }
        dict[.string("block")] = blockP
        return .orderedDict(dict)
    }
}
