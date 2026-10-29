import Foundation
import OrderedCollections
import CBORCodable

/// A Cardano block header from any era, decoded from the NtN wire format.
///
/// NtN ChainSync delivers block headers only (not full blocks). The wire format
/// is era-prefixed for Shelley+ and discriminant-prefixed for Byron:
///
/// **Byron NtN** — the raw bytes are `[[discriminant, blockSize], #6.24(head_bytes)]`:
/// ```
///   discriminant 0 → EBB, 1 → BFT; blockSize is the size of the whole block in bytes
/// ```
///
/// **Shelley+ NtN** — the raw bytes are `[[era, #6.24(header_cbor)], kes_sig]`,
/// which is the standard `Header` wire format decoded by `Header.fromCBOR`.
///
/// Use `decodeEraHeader()` on a `RawBlock` from an NtN `ChainSyncClient` to
/// obtain a fully-typed `EraBlockHeader`.
public enum EraBlockHeader: Sendable {
    case byron(ByronBlockHeader)
    case shelley(Header)
    case allegra(Header)
    case mary(Header)
    case alonzo(Header)
    case babbage(Header)
    case conway(Header)

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

    /// The Shelley+ typed header, or `nil` for Byron.
    public var header: Header? {
        switch self {
        case .byron: return nil
        case .shelley(let h),
            .allegra(let h),
            .mary(let h),
            .alonzo(let h),
            .babbage(let h),
            .conway(let h):
            return h
        }
    }

    /// The Byron block header, or `nil` for Shelley+.
    public var byronHeader: ByronBlockHeader? {
        guard case .byron(let h) = self else { return nil }
        return h
    }

    // MARK: - Byron NtN parsing

    /// Parse a `ByronBlockHeader` from NtN raw bytes, keeping the header's bytes.
    ///
    /// `data` must be the full `[[discriminant, blockSize], #6.24(head_bytes)]`
    /// 2-element array as delivered by the NtN ChainSync protocol for era 0.
    ///
    /// - Returns: `.byron(.ebb(_))` or `.byron(.bft(_))`
    /// - Throws: `CardanoCoreError.deserializeError` if the bytes are malformed.
    public static func fromByronNtNData(_ data: Data) throws -> EraBlockHeader {
        let item = try ByronCBORItem(root: data, "EraBlockHeader Byron NtN")
        let block = try ByronBlock.decodeHeaderOnly(
            try item.array("EraBlockHeader Byron NtN", count: 2), bytes: item.bytes)
        return .byron(block.header)
    }

    // MARK: - Shared helpers

    private static func unwrapEmbeddedCBOR(_ primitive: Primitive) throws -> Data {
        switch primitive {
        case .cborTag(let tag):
            guard tag.tag == 24 else {
                throw CardanoCoreError.deserializeError(
                    "EraBlockHeader: expected tag-24, got tag \(tag.tag)"
                )
            }
            guard case .bytes(let bytes) = tag.value else {
                throw CardanoCoreError.deserializeError(
                    "EraBlockHeader: tag-24 value must be bytes"
                )
            }
            return bytes
        case .bytes(let bytes):
            return bytes
        default:
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader: expected tag-24 or bytes for embedded CBOR"
            )
        }
    }
}

// MARK: - Equatable & Hashable

extension EraBlockHeader: Equatable, Hashable {}

// MARK: - Serializable

extension EraBlockHeader: Serializable {

    // MARK: CBORSerializable

    /// Decode from the canonical era-wrapped format: `[era_id, #6.24(header_cbor)]`.
    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader: expected [era_id, #6.24(header)] 2-element array"
            )
        }
        let eraId: UInt64
        switch elements[0] {
        case .uint(let v): eraId = UInt64(v)
        case .int(let v): eraId = UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("EraBlockHeader: era_id must be uint")
        }
        let headerBytes = try Self.unwrapEmbeddedCBOR(elements[1])
        switch eraId {
        case 0:
            self = .byron(try ByronBlockHeader.fromCBOR(data: headerBytes))
        case 1: self = .shelley(try Header.fromCBOR(data: headerBytes))
        case 2: self = .allegra(try Header.fromCBOR(data: headerBytes))
        case 3: self = .mary(try Header.fromCBOR(data: headerBytes))
        case 4: self = .alonzo(try Header.fromCBOR(data: headerBytes))
        case 5: self = .babbage(try Header.fromCBOR(data: headerBytes))
        case 6: self = .conway(try Header.fromCBOR(data: headerBytes))
        default:
            throw CardanoCoreError.deserializeError("EraBlockHeader: unknown era id \(eraId)")
        }
    }

    /// Encode to `[era_id, #6.24(header_cbor)]`.
    public func toPrimitive() throws -> Primitive {
        let innerBytes: Data
        switch self {
        case .byron(let h): innerBytes = try h.toCBORData()
        case .shelley(let h),
            .allegra(let h),
            .mary(let h),
            .alonzo(let h),
            .babbage(let h),
            .conway(let h):
            innerBytes = try h.toCBORData()
        }
        return .list([
            .uint(UInt64(eraId)),
            .cborTag(CBORTag(tag: 24, value: .bytes(innerBytes))),
        ])
    }

    // MARK: JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> EraBlockHeader {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("EraBlockHeader.fromDict: expected dict")
        }
        guard let eraP = dict[.string("era")] else {
            throw CardanoCoreError.deserializeError("EraBlockHeader.fromDict: missing 'era' field")
        }
        let eraId: UInt64
        switch eraP {
        case .uint(let v): eraId = UInt64(v)
        case .int(let v): eraId = UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("EraBlockHeader.fromDict: 'era' must be uint")
        }
        guard let headerP = dict[.string("header")] else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader.fromDict: missing 'header' field")
        }
        switch eraId {
        case 0: return .byron(try ByronBlockHeader.fromDict(headerP))
        case 1: return .shelley(try Header.fromDict(headerP))
        case 2: return .allegra(try Header.fromDict(headerP))
        case 3: return .mary(try Header.fromDict(headerP))
        case 4: return .alonzo(try Header.fromDict(headerP))
        case 5: return .babbage(try Header.fromDict(headerP))
        case 6: return .conway(try Header.fromDict(headerP))
        default:
            throw CardanoCoreError.deserializeError("EraBlockHeader.fromDict: unknown era \(eraId)")
        }
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("era")] = .uint(UInt64(eraId))
        let headerP: Primitive
        switch self {
        case .byron(let h): headerP = try h.toDict()
        case .shelley(let h),
            .allegra(let h),
            .mary(let h),
            .alonzo(let h),
            .babbage(let h),
            .conway(let h):
            headerP = try h.toDict()
        }
        dict[.string("header")] = headerP
        return .orderedDict(dict)
    }
}
