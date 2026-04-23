import Foundation
import OrderedCollections
import PotentCBOR

/// A Cardano block header from any era, decoded from the NtN wire format.
///
/// NtN ChainSync delivers block headers only (not full blocks). The wire format
/// is era-prefixed for Shelley+ and discriminant-prefixed for Byron:
///
/// **Byron NtN** — the raw bytes are `[[discriminant, epochOrSlot], #6.24(head_bytes)]`:
/// ```
///   discriminant 0 → EBB,  epochOrSlot = epoch number
///   discriminant 1 → BFT,  epochOrSlot = absolute slot
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

    /// Parse a `ByronBlockHeader` from NtN raw bytes.
    ///
    /// `data` must be the full `[[discriminant, epochOrSlot], #6.24(head_bytes)]`
    /// 2-element array as delivered by the NtN ChainSync protocol for era 0.
    ///
    /// - Returns: `.byron(.ebb(_))` or `.byron(.bft(_))`
    /// - Throws: `CardanoCoreError.deserializeError` if the bytes are malformed.
    public static func fromByronNtNData(_ data: Data) throws -> EraBlockHeader {
        let primitive = try CBORDecoder().decode(Primitive.self, from: data)

        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader Byron NtN: expected 2-element outer array"
            )
        }
        guard case .list(let framingElements) = elements[0], framingElements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader Byron NtN: expected [discriminant, epochOrSlot] framing array"
            )
        }

        let discriminant = try requireUInt(framingElements[0])
        let epochOrSlot = try requireUInt(framingElements[1])

        let headData = try unwrapEmbeddedCBOR(elements[1])
        let headPrimitive = try CBORDecoder().decode(Primitive.self, from: headData)

        guard case .list(let headElements) = headPrimitive, headElements.count >= 5 else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader Byron NtN: head must be a ≥5-element array, "
                    + "got \((headPrimitive as Any))"
            )
        }

        if discriminant == 0 {
            let ebb = try parseEBBHead(headElements: headElements, absoluteSlot: epochOrSlot)
            return .byron(.ebb(ebb))
        } else {
            let bft = try parseBFTHead(headElements: headElements, absoluteSlot: epochOrSlot)
            return .byron(.bft(bft))
        }
    }

    // MARK: - EBB head parsing

    /// Parse an `EBBHead` from the 5-element `ebbhead` CBOR array.
    ///
    /// ```
    /// ebbhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
    ///   ebbcons = [epoch : uint, difficulty : [uint]]
    /// ```
    private static func parseEBBHead(
        headElements: [Primitive],
        absoluteSlot: UInt64?
    ) throws -> ByronBlockHeader.EBBHead {
        let protocolMagic = UInt32(try requireUInt(headElements[0]))
        let prevBlock = bytesOrNil(headElements[1])
        let bodyProof = try Self.primitiveToData(headElements[2])

        guard case .list(let cons) = headElements[3], cons.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "EBBHead: consensusData must be a 2-element array [epoch, difficulty]"
            )
        }
        let epoch = try requireUInt(cons[0])
        let difficulty = try extractDifficulty(cons[1])

        return ByronBlockHeader.EBBHead(
            protocolMagic: protocolMagic,
            prevBlock: prevBlock,
            bodyProof: bodyProof,
            epoch: epoch,
            difficulty: difficulty,
            absoluteSlot: absoluteSlot
        )
    }

    // MARK: - BFT head parsing

    /// Parse a `BFTHead` from the 5-element `blockhead` CBOR array.
    ///
    /// ```
    /// blockhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
    ///   blockcons = [slotId, pubkey, difficulty, blocksig]
    ///   slotId    = [epoch : uint, slot : uint]
    ///   pubkey    = bytes .size 64
    ///   blocksig  = [0, sig] / [1, lwdlgsig] / [2, dlgsig]
    ///   blockheadex = [blockVersion, softwareVersion, attributes, extraProof]
    /// ```
    private static func parseBFTHead(
        headElements: [Primitive],
        absoluteSlot: UInt64?
    ) throws -> ByronBlockHeader.BFTHead {
        let protocolMagic = UInt32(try requireUInt(headElements[0]))
        let prevBlock = bytesOrNil(headElements[1])
        let bodyProof = try Self.primitiveToData(headElements[2])

        guard case .list(let cons) = headElements[3], cons.count >= 4 else {
            throw CardanoCoreError.deserializeError(
                "BFTHead: consensusData must be a 4-element array [slotId, pubkey, difficulty, blocksig]"
            )
        }

        // slotId = [epoch, slotWithinEpoch]
        guard case .list(let slotElements) = cons[0], slotElements.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "BFTHead: slotId must be a 2-element array [epoch, slot]"
            )
        }
        let slotId = ByronBlockHeader.SlotId(
            epoch: try requireUInt(slotElements[0]),
            slot: try requireUInt(slotElements[1])
        )

        guard case .bytes(let issuerKey) = cons[1] else {
            throw CardanoCoreError.deserializeError(
                "BFTHead: pubkey (consensusData[1]) must be bytes"
            )
        }

        let difficulty = try extractDifficulty(cons[2])
        let signature = try parseBlockSignature(cons[3])

        // extraData = [blockVersion, softwareVersion, attributes, extraProof]
        let blockVersion: ByronBlockHeader.BlockVersion
        let softwareVersion: ByronBlockHeader.SoftwareVersion

        if case .list(let extra) = headElements[4], extra.count >= 2 {
            blockVersion = parseBlockVersion(extra[0])
            softwareVersion = parseSoftwareVersion(extra[1])
        } else {
            blockVersion = .zero
            softwareVersion = .unknown
        }

        return ByronBlockHeader.BFTHead(
            protocolMagic: protocolMagic,
            prevBlock: prevBlock,
            bodyProof: bodyProof,
            slotId: slotId,
            issuerKey: issuerKey,
            difficulty: difficulty,
            signature: signature,
            blockVersion: blockVersion,
            softwareVersion: softwareVersion,
            absoluteSlot: absoluteSlot
        )
    }

    // MARK: - BlockSignature parsing

    private static func parseBlockSignature(_ primitive: Primitive) throws
        -> ByronBlockHeader.BlockSignature
    {
        guard case .list(let elements) = primitive, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "BlockSignature: expected [kind, payload] array"
            )
        }
        let kind = try requireUInt(elements[0])
        switch kind {
        case 0:
            guard case .bytes(let sig) = elements[1] else {
                throw CardanoCoreError.deserializeError(
                    "BlockSignature regular: payload must be bytes"
                )
            }
            return .regular(sig)
        case 1:
            return .lightweightDelegation(try parseLwDlgSig(elements[1]))
        case 2:
            return .delegation(try parseDlgSig(elements[1]))
        default:
            throw CardanoCoreError.deserializeError(
                "BlockSignature: unknown kind \(kind)"
            )
        }
    }

    private static func parseDlgSig(_ primitive: Primitive) throws -> ByronBlockHeader.DlgSig {
        guard case .list(let elements) = primitive, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError("DlgSig: expected [dlg, signature]")
        }
        let dlg = try parseDlg(elements[0])
        guard case .bytes(let sig) = elements[1] else {
            throw CardanoCoreError.deserializeError("DlgSig: signature must be bytes")
        }
        return ByronBlockHeader.DlgSig(delegation: dlg, signature: sig)
    }

    private static func parseDlg(_ primitive: Primitive) throws -> ByronBlockHeader.Dlg {
        guard case .list(let elements) = primitive, elements.count >= 4 else {
            throw CardanoCoreError.deserializeError(
                "Dlg: expected [epoch, issuer, delegate, certificate]"
            )
        }
        let epoch = try requireUInt(elements[0])
        guard case .bytes(let issuer) = elements[1],
            case .bytes(let delegate) = elements[2],
            case .bytes(let cert) = elements[3]
        else {
            throw CardanoCoreError.deserializeError(
                "Dlg: issuer, delegate, certificate must all be bytes"
            )
        }
        return ByronBlockHeader.Dlg(
            epoch: epoch, issuer: issuer, delegate: delegate, certificate: cert)
    }

    private static func parseLwDlgSig(_ primitive: Primitive) throws -> ByronBlockHeader.LwDlgSig {
        guard case .list(let elements) = primitive, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError("LwDlgSig: expected [lwdlg, signature]")
        }
        let lwdlg = try parseLwDlg(elements[0])
        guard case .bytes(let sig) = elements[1] else {
            throw CardanoCoreError.deserializeError("LwDlgSig: signature must be bytes")
        }
        return ByronBlockHeader.LwDlgSig(delegation: lwdlg, signature: sig)
    }

    private static func parseLwDlg(_ primitive: Primitive) throws -> ByronBlockHeader.LwDlg {
        guard case .list(let elements) = primitive, elements.count >= 4 else {
            throw CardanoCoreError.deserializeError(
                "LwDlg: expected [[epochFrom, epochTo], issuer, delegate, certificate]"
            )
        }
        guard case .list(let epochRange) = elements[0], epochRange.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "LwDlg: epochRange must be [epochFrom, epochTo]"
            )
        }
        let epochFrom = try requireUInt(epochRange[0])
        let epochTo = try requireUInt(epochRange[1])
        guard case .bytes(let issuer) = elements[1],
            case .bytes(let delegate) = elements[2],
            case .bytes(let cert) = elements[3]
        else {
            throw CardanoCoreError.deserializeError(
                "LwDlg: issuer, delegate, certificate must all be bytes"
            )
        }
        return ByronBlockHeader.LwDlg(
            epochFrom: epochFrom,
            epochTo: epochTo,
            issuer: issuer,
            delegate: delegate,
            certificate: cert
        )
    }

    // MARK: - Version parsing

    private static func parseBlockVersion(_ primitive: Primitive) -> ByronBlockHeader.BlockVersion {
        guard case .list(let bv) = primitive, bv.count >= 3,
            let major = try? requireUInt(bv[0]),
            let minor = try? requireUInt(bv[1]),
            let alt = try? requireUInt(bv[2])
        else { return .zero }
        return ByronBlockHeader.BlockVersion(
            major: UInt16(major), minor: UInt16(minor), alt: UInt8(alt)
        )
    }

    private static func parseSoftwareVersion(_ primitive: Primitive)
        -> ByronBlockHeader.SoftwareVersion
    {
        guard case .list(let sv) = primitive, sv.count >= 2,
            case .string(let appName) = sv[0],
            let number = try? requireUInt(sv[1])
        else { return .unknown }
        return ByronBlockHeader.SoftwareVersion(appName: appName, number: UInt32(number))
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

    private static func requireUInt(_ primitive: Primitive) throws -> UInt64 {
        switch primitive {
        case .uint(let val): return UInt64(val)
        case .int(let val): return UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader: expected uint, got \(primitive)"
            )
        }
    }

    private static func bytesOrNil(_ primitive: Primitive) -> Data? {
        guard case .bytes(let data) = primitive, !data.isEmpty else { return nil }
        return data
    }

    private static func bytesOrEmpty(_ primitive: Primitive) -> Data {
        guard case .bytes(let data) = primitive else { return Data() }
        return data
    }

    /// Re-encodes `p` to CBOR bytes if it is not already a `.bytes` primitive.
    /// `blockproof` on the wire is a list structure, not raw bytes.
    private static func primitiveToData(_ p: Primitive) throws -> Data {
        if case .bytes(let d) = p { return d }
        return try CBOREncoder().encode(p)
    }

    private static func extractDifficulty(_ primitive: Primitive) throws -> UInt64 {
        guard case .list(let elements) = primitive, let first = elements.first else {
            throw CardanoCoreError.deserializeError(
                "EraBlockHeader: chainDifficulty must be [uint]"
            )
        }
        return try requireUInt(first)
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
            let primitive = try CBORDecoder().decode(Primitive.self, from: headerBytes)
            self = .byron(try ByronBlockHeader(from: primitive))
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
            .uint(UInt(eraId)),
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
        dict[.string("era")] = .uint(UInt(eraId))
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
