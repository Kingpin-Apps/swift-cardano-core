import Foundation
import OrderedCollections
import PotentCBOR

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
/// Shelley through Conway share the same 5-element `Block` body structure;
/// era differences are confined to `HeaderBody` field count (14 vs 15).
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
/// [[discriminant, epochOrSlot], #6.24(head_bytes)]
///   discriminant 0 → EBB,  epochOrSlot = epoch
///   discriminant 1 → BFT,  epochOrSlot = absolute slot
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
        let primitive = try CBORDecoder().decode(Primitive.self, from: data)

        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlock: expected [era_id, #6.24(block)] 2-element array"
            )
        }

        let eraId: UInt64
        switch elements[0] {
        case .uint(let val): eraId = UInt64(val)
        case .int(let val): eraId = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError("EraBlock: era_id must be uint")
        }

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
            return .shelley(try Block.fromCBOR(data: data))
        case 2:
            return .allegra(try Block.fromCBOR(data: data))
        case 3:
            return .mary(try Block.fromCBOR(data: data))
        case 4:
            return .alonzo(try Block.fromCBOR(data: data))
        case 5:
            return .babbage(try Block.fromCBOR(data: data))
        case 6:
            return .conway(try Block.fromCBOR(data: data))
        default:
            throw CardanoCoreError.deserializeError("EraBlock: unknown era id \(era)")
        }
    }

    // MARK: - Byron parsing

    /// Parse a `ByronBlock` from raw bytes.
    ///
    /// Detects the wire format by the type of `elements[0]`:
    /// - **`.uint`** → NtC: `[discriminant, block_content]` (both EBB and BFT are 2-element)
    /// - **`.list`** → NtN: `[[discriminant, epochOrSlot], #6.24(head)]`
    private static func parseByronBlock(data: Data) throws -> ByronBlock {
        let primitive = try CBORDecoder().decode(Primitive.self, from: data)

        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock: expected 2-element CBOR array at top level"
            )
        }

        switch elements[0] {
        case .uint(let discriminant):
            // NtC full block: [discriminant, block_content]
            return try parseByronNtCBlock(discriminant: UInt64(discriminant), content: elements[1])
        case .list:
            // NtN header: [[discriminant, epochOrSlot], tag24(head)]
            return try parseByronNtNHeader(elements: elements)
        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlock: unexpected top-level element type (expected uint or list)"
            )
        }
    }

    /// Parse the NtN Byron header format: `[[discriminant, epochOrSlot], #6.24(head_bytes)]`.
    ///
    /// - discriminant 0 → EBB, epochOrSlot is the epoch number
    /// - discriminant 1 → BFT, epochOrSlot is the absolute slot from NtN framing
    private static func parseByronNtNHeader(elements: [Primitive]) throws -> ByronBlock {
        guard case .list(let framingElements) = elements[0], framingElements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock NtN: expected [discriminant, epochOrSlot] inner array"
            )
        }

        let discriminant = try requireUInt(framingElements[0])
        let epochOrSlot = try requireUInt(framingElements[1])

        let headData = try unwrapEmbeddedCBOR(elements[1])
        let headPrimitive = try CBORDecoder().decode(Primitive.self, from: headData)

        guard case .list(let headElements) = headPrimitive else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock NtN: decoded head must be a CBOR array"
            )
        }

        if discriminant == 0 {
            // EBB — epochOrSlot is the epoch number
            return .ebb(try parseEBBHead(headElements: headElements, epochHint: epochOrSlot))
        } else {
            // BFT — epochOrSlot is the absolute slot from the NtN framing
            return .bft(
                try parseBFTHead(
                    headElements: headElements,
                    absoluteSlot: epochOrSlot,
                    transactionCount: 0
                )
            )
        }
    }

    /// Parse a NtC Byron block: `[discriminant, block_content]`.
    ///
    /// `block_content` is `ebblock = [ebbhead, ebbbody, ebbatts]`
    /// or `mainblock = [blockhead, blockbody, blockextra]`.
    /// The discriminant (0 = EBB, 1 = BFT) is used to select the parser — both
    /// `ebbhead` and `blockhead` are 5-element arrays, so counting elements is not
    /// a reliable discriminant.
    private static func parseByronNtCBlock(discriminant: UInt64, content: Primitive) throws
        -> ByronBlock
    {
        guard case .list(let blockElements) = content, !blockElements.isEmpty,
            case .list(let headElements) = blockElements[0]
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock NtC: block content must be array with head as first element"
            )
        }

        if discriminant == 0 {
            return .ebb(try parseEBBHead(headElements: headElements, epochHint: nil))
        } else {
            let txCount = blockElements.count >= 2 ? extractByronTxCount(from: blockElements[1]) : 0
            return .bft(
                try parseBFTHead(
                    headElements: headElements,
                    absoluteSlot: nil,
                    transactionCount: txCount
                )
            )
        }
    }

    /// Parse an EBB head (5-element array per the Byron CDDL).
    ///
    /// ```
    /// ebbhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
    ///   consensusData = [epoch : uint, chainDifficulty : [uint]]
    /// ```
    private static func parseEBBHead(
        headElements: [Primitive],
        epochHint: UInt64?
    ) throws -> ByronBlock.EBB {
        guard headElements.count >= 5 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock EBB: head requires at least 5 elements, got \(headElements.count)"
            )
        }

        let protocolMagic = UInt32(try requireUInt(headElements[0]))
        let prevHash = bytesOrNil(headElements[1])

        // [3] consensusData = [epoch, [difficulty]]
        guard case .list(let consensusElements) = headElements[3],
            consensusElements.count >= 2
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock EBB: consensusData must be a 2-element array"
            )
        }

        let epoch: UInt64
        if let hint = epochHint {
            epoch = hint
        } else {
            epoch = try requireUInt(consensusElements[0])
        }
        let difficulty = try extractDifficulty(consensusElements[1])

        return ByronBlock.EBB(
            protocolMagic: protocolMagic,
            prevHash: prevHash,
            epoch: epoch,
            difficulty: difficulty
        )
    }

    /// Parse a BFT block head (5-element array).
    ///
    /// ```
    /// blockhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
    ///   consensusData = [slotId, issuer, chainDifficulty, signature]
    ///   slotId        = [epoch : uint, slotWithinEpoch : uint]
    ///   issuer        = bytes .size 64
    ///   chainDifficulty = [uint]
    ///   extraData     = [blockVersion, softwareVersion, attributes, extraProof]
    ///   blockVersion  = [major : uint, minor : uint, alt : uint]
    ///   softwareVersion = [appName : text, number : uint]
    /// ```
    private static func parseBFTHead(
        headElements: [Primitive],
        absoluteSlot: UInt64?,
        transactionCount: Int
    ) throws -> ByronBlock.BFT {
        guard headElements.count >= 5 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock BFT: head requires at least 5 elements, got \(headElements.count)"
            )
        }

        let protocolMagic = UInt32(try requireUInt(headElements[0]))
        let prevHash = bytesOrNil(headElements[1])

        // [3] consensusData = [slotId, issuer, chainDifficulty, signature]
        guard case .list(let consensusElements) = headElements[3],
            consensusElements.count >= 3
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock BFT: consensusData must be an array with at least 3 elements"
            )
        }

        // slotId = [epoch, slotWithinEpoch]
        guard case .list(let slotElements) = consensusElements[0],
            slotElements.count >= 2
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock BFT: slotId must be a 2-element array [epoch, slotWithinEpoch]"
            )
        }
        let epoch = try requireUInt(slotElements[0])
        let slotWithinEpoch = try requireUInt(slotElements[1])

        // issuer = bytes(64)
        guard case .bytes(let issuerVKey) = consensusElements[1] else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock BFT: issuer (consensusData[1]) must be bytes"
            )
        }

        let difficulty = try extractDifficulty(consensusElements[2])

        // [4] extraData = [blockVersion, softwareVersion, attributes, extraProof]
        let protocolVersion: ByronBlock.ByronProtocolVersion
        let softwareVersion: ByronBlock.ByronSoftwareVersion

        if case .list(let extraElements) = headElements[4], extraElements.count >= 2 {
            // blockVersion = [major, minor, alt]
            if case .list(let bv) = extraElements[0], bv.count >= 3,
                let major = try? requireUInt(bv[0]),
                let minor = try? requireUInt(bv[1]),
                let alt = try? requireUInt(bv[2])
            {
                protocolVersion = ByronBlock.ByronProtocolVersion(
                    major: UInt16(major),
                    minor: UInt16(minor),
                    alt: UInt16(alt)
                )
            } else {
                protocolVersion = .zero
            }

            // softwareVersion = [appName, number]
            if case .list(let sv) = extraElements[1], sv.count >= 2,
                case .string(let appName) = sv[0],
                let number = try? requireUInt(sv[1])
            {
                softwareVersion = ByronBlock.ByronSoftwareVersion(
                    appName: appName,
                    number: UInt32(number)
                )
            } else {
                softwareVersion = .unknown
            }
        } else {
            protocolVersion = .zero
            softwareVersion = .unknown
        }

        return ByronBlock.BFT(
            protocolMagic: protocolMagic,
            prevHash: prevHash,
            epoch: epoch,
            slotWithinEpoch: slotWithinEpoch,
            absoluteSlot: absoluteSlot,
            issuerVKey: issuerVKey,
            difficulty: difficulty,
            protocolVersion: protocolVersion,
            softwareVersion: softwareVersion,
            transactionCount: transactionCount
        )
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

    /// Unwrap embedded CBOR from a tag-24 primitive or raw bytes.
    /// Used for the Byron head bytes inside `[[discriminant, epochOrSlot], payload]`.
    private static func unwrapEmbeddedCBOR(_ primitive: Primitive) throws -> Data {
        try unwrapTag24(primitive)
    }

    /// Extract the `uint` value from a `Primitive`, throwing on mismatch.
    private static func requireUInt(_ primitive: Primitive) throws -> UInt64 {
        switch primitive {
        case .uint(let val): return UInt64(val)
        case .int(let val): return UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "EraBlock: expected uint, got \(primitive)"
            )
        }
    }

    /// Return bytes from a primitive, or `nil` if the value is null or empty.
    private static func bytesOrNil(_ primitive: Primitive) -> Data? {
        guard case .bytes(let data) = primitive, !data.isEmpty else { return nil }
        return data
    }

    /// Extract the uint from a `chainDifficulty = [uint]` single-element array.
    private static func extractDifficulty(_ primitive: Primitive) throws -> UInt64 {
        guard case .list(let elements) = primitive, let first = elements.first else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock: chainDifficulty must be a single-element array [uint]"
            )
        }
        return try requireUInt(first)
    }

    /// Count transactions from a Byron block body primitive.
    ///
    /// Byron block body structure: `[txPayload, sscPayload, dlgPayload, updPayload]`
    /// where `txPayload = [* tx]`.
    private static func extractByronTxCount(from bodyPrimitive: Primitive) -> Int {
        guard case .list(let bodyElements) = bodyPrimitive,
            let txPayload = bodyElements.first,
            case .list(let txs) = txPayload
        else { return 0 }
        return txs.count
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
        let eraId: UInt64
        switch elements[0] {
        case .uint(let v): eraId = UInt64(v)
        case .int(let v): eraId = UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("EraBlock: era_id must be uint")
        }
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
            .uint(UInt(eraId)),
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
        let eraId: UInt64
        switch eraP {
        case .uint(let v): eraId = UInt64(v)
        case .int(let v): eraId = UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("EraBlock.fromDict: 'era' must be uint")
        }
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
        dict[.string("era")] = .uint(UInt(eraId))
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
