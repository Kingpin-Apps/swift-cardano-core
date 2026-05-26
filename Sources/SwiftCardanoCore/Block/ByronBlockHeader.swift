import Foundation
import OrderedCollections
import CBORCodable
import SwiftNcal

/// A parsed Byron era block header — either an Epoch Boundary Block header or a
/// regular BFT block header.
///
/// Derived from the official Byron CDDL specification:
/// https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/byron/ledger/impl/cddl-spec/byron.cddl
///
/// Both header types share the same 5-element CBOR array shape but differ in
/// the structure of `consensusData` and `extraData`:
///
/// ```
/// ebbhead  = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
///   ebbcons  = [epochid, difficulty]
///
/// blockhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
///   blockcons = [slotid, pubkey, difficulty, blocksig]
///   blockheadex = [blockVersion, softwareVersion, attributes, extraProof]
/// ```
///
/// The discriminant (0 = EBB, 1 = BFT) comes from the outer block wrapper
/// (`block = [0, ebblock] / [1, mainblock]`) or from the NtN framing
/// (`[[0|1, epochOrSlot], tag24(head)]`).
public enum ByronBlockHeader: Sendable {
    case ebb(EBBHead)
    case bft(BFTHead)

    // MARK: - EBBHead

    /// Parsed `ebbhead` — the header of an Epoch Boundary Block.
    ///
    /// ```
    /// ebbhead = [ protocolMagic : u32
    ///           , prevBlock      : blockid       ; blake2b-256 (32 bytes)
    ///           , bodyProof      : hash           ; blake2b-256 (32 bytes)
    ///           , consensusData  : ebbcons        ; [epochid, difficulty]
    ///           , extraData      : [attributes]
    ///           ]
    /// ebbcons    = [epochid, difficulty]
    /// difficulty = [u64]
    /// ```
    public struct EBBHead: Sendable {
        /// Network protocol magic.
        public let protocolMagic: UInt32
        /// Previous block id (blake2b-256, 32 bytes). Nil at genesis.
        public let prevBlock: Data?
        /// Body proof hash (blake2b-256, 32 bytes).
        public let bodyProof: Data
        /// Epoch number from `ebbcons[0]`.
        public let epoch: UInt64
        /// Chain difficulty (block height) from `ebbcons[1] = [u64]`.
        public let difficulty: UInt64
        /// Absolute slot number from NtN framing. Nil when decoded from an NtC full block.
        public let absoluteSlot: UInt64?

        public init(
            protocolMagic: UInt32,
            prevBlock: Data?,
            bodyProof: Data,
            epoch: UInt64,
            difficulty: UInt64,
            absoluteSlot: UInt64?
        ) {
            self.protocolMagic = protocolMagic
            self.prevBlock = prevBlock
            self.bodyProof = bodyProof
            self.epoch = epoch
            self.difficulty = difficulty
            self.absoluteSlot = absoluteSlot
        }
    }

    // MARK: - BFTHead

    /// Parsed `blockhead` — the header of a regular Byron BFT block.
    ///
    /// ```
    /// blockhead = [ protocolMagic : u32
    ///             , prevBlock      : blockid
    ///             , bodyProof      : blockproof
    ///             , consensusData  : blockcons
    ///             , extraData      : blockheadex
    ///             ]
    /// blockcons   = [slotid, pubkey, difficulty, blocksig]
    /// slotid      = [epoch : u64, slot : u64]
    /// blockheadex = [blockVersion, softwareVersion, attributes, extraProof]
    /// bver        = [u16, u16, u8]
    /// ```
    public struct BFTHead: Sendable {
        /// Network protocol magic.
        public let protocolMagic: UInt32
        /// Previous block id (blake2b-256). Nil at genesis.
        public let prevBlock: Data?
        /// Block body proof (`blockproof`) — blake2b-256 hash of the block body.
        public let bodyProof: Data
        /// Slot identifier — epoch number and slot within epoch.
        public let slotId: SlotId
        /// Block issuer public key (`pubkey` in `blockcons`).
        /// This is the hot key that actually signed the block (the BFT delegate).
        public let issuerKey: Data
        /// Chain difficulty (block height).
        public let difficulty: UInt64
        /// Block signature — encodes the delegation chain.
        public let signature: BlockSignature
        /// Protocol version from `blockheadex.blockVersion`.
        public let blockVersion: BlockVersion
        /// Software version from `blockheadex.softwareVersion`.
        public let softwareVersion: SoftwareVersion
        /// Absolute slot number from NtN framing. Nil when decoded from an NtC full block.
        public let absoluteSlot: UInt64?

        public init(
            protocolMagic: UInt32,
            prevBlock: Data?,
            bodyProof: Data,
            slotId: SlotId,
            issuerKey: Data,
            difficulty: UInt64,
            signature: BlockSignature,
            blockVersion: BlockVersion,
            softwareVersion: SoftwareVersion,
            absoluteSlot: UInt64?
        ) {
            self.protocolMagic = protocolMagic
            self.prevBlock = prevBlock
            self.bodyProof = bodyProof
            self.slotId = slotId
            self.issuerKey = issuerKey
            self.difficulty = difficulty
            self.signature = signature
            self.blockVersion = blockVersion
            self.softwareVersion = softwareVersion
            self.absoluteSlot = absoluteSlot
        }
    }

    // MARK: - Supporting types

    /// Byron slot identifier: epoch number + slot within that epoch.
    ///
    /// `slotid = [epoch : epochid, slot : u64]`
    public struct SlotId: Sendable {
        public let epoch: UInt64
        public let slot: UInt64

        public init(epoch: UInt64, slot: UInt64) {
            self.epoch = epoch
            self.slot = slot
        }
    }

    /// Byron block version.
    ///
    /// `bver = [u16, u16, u8]`
    public struct BlockVersion: Sendable {
        public let major: UInt16
        public let minor: UInt16
        public let alt: UInt8

        public init(major: UInt16, minor: UInt16, alt: UInt8) {
            self.major = major
            self.minor = minor
            self.alt = alt
        }

        public static let zero = BlockVersion(major: 0, minor: 0, alt: 0)
    }

    /// Byron software version.
    ///
    /// `softwareVersion = [text, u32]`
    public struct SoftwareVersion: Sendable {
        public let appName: String
        public let number: UInt32

        public init(appName: String, number: UInt32) {
            self.appName = appName
            self.number = number
        }

        public static let unknown = SoftwareVersion(appName: "", number: 0)
    }

    /// Byron block signature.
    ///
    /// ```
    /// blocksig = [0, signature]    ; plain BFT signature
    ///          / [1, lwdlgsig]     ; lightweight delegation signature
    ///          / [2, dlgsig]       ; heavy delegation signature (most common)
    /// ```
    public enum BlockSignature: Sendable {
        /// Plain BFT signature: `[0, signature]`
        case regular(Data)
        /// Lightweight (short-range) delegation: `[1, lwdlgsig]`
        case lightweightDelegation(LwDlgSig)
        /// Heavy delegation certificate: `[2, dlgsig]`
        case delegation(DlgSig)
    }

    /// Heavy delegation signature: `dlgsig = [dlg, signature]`
    public struct DlgSig: Sendable {
        public let delegation: Dlg
        public let signature: Data

        public init(delegation: Dlg, signature: Data) {
            self.delegation = delegation
            self.signature = signature
        }
    }

    /// Lightweight delegation signature: `lwdlgsig = [lwdlg, signature]`
    public struct LwDlgSig: Sendable {
        public let delegation: LwDlg
        public let signature: Data

        public init(delegation: LwDlg, signature: Data) {
            self.delegation = delegation
            self.signature = signature
        }
    }

    /// Heavy delegation certificate.
    ///
    /// ```
    /// dlg = [epoch : epochid, issuer : pubkey, delegate : pubkey, certificate : signature]
    /// ```
    public struct Dlg: Sendable {
        /// Epoch the delegation is valid for.
        public let epoch: UInt64
        /// Cold verification key (genesis key holder).
        public let issuer: Data
        /// Hot verification key (actual block producer).
        public let delegate: Data
        /// Signature from the issuer over the delegation.
        public let certificate: Data

        public init(epoch: UInt64, issuer: Data, delegate: Data, certificate: Data) {
            self.epoch = epoch
            self.issuer = issuer
            self.delegate = delegate
            self.certificate = certificate
        }
    }

    /// Lightweight (short-range) delegation certificate.
    ///
    /// ```
    /// lwdlg = [epochRange : [epochid, epochid], issuer : pubkey,
    ///          delegate : pubkey, certificate : signature]
    /// ```
    public struct LwDlg: Sendable {
        /// First epoch in the delegation range.
        public let epochFrom: UInt64
        /// Last epoch in the delegation range.
        public let epochTo: UInt64
        /// Issuer cold key.
        public let issuer: Data
        /// Delegate hot key.
        public let delegate: Data
        /// Signature from the issuer.
        public let certificate: Data

        public init(
            epochFrom: UInt64, epochTo: UInt64, issuer: Data, delegate: Data, certificate: Data
        ) {
            self.epochFrom = epochFrom
            self.epochTo = epochTo
            self.issuer = issuer
            self.delegate = delegate
            self.certificate = certificate
        }
    }

    // MARK: - Convenience accessors

    /// Previous block id regardless of variant.
    public var prevBlock: Data? {
        switch self {
        case .ebb(let h): return h.prevBlock
        case .bft(let h): return h.prevBlock
        }
    }

    /// Chain difficulty (block height) regardless of variant.
    public var difficulty: UInt64 {
        switch self {
        case .ebb(let h): return h.difficulty
        case .bft(let h): return h.difficulty
        }
    }

    /// Absolute slot from NtN framing (nil for NtC).
    public var absoluteSlot: UInt64? {
        switch self {
        case .ebb(let h): return h.absoluteSlot
        case .bft(let h): return h.absoluteSlot
        }
    }
}

// MARK: - Equatable & Hashable

extension ByronBlockHeader.SlotId: Equatable, Hashable {}
extension ByronBlockHeader.BlockVersion: Equatable, Hashable {}
extension ByronBlockHeader.SoftwareVersion: Equatable, Hashable {}
extension ByronBlockHeader.Dlg: Equatable, Hashable {}
extension ByronBlockHeader.DlgSig: Equatable, Hashable {}
extension ByronBlockHeader.LwDlg: Equatable, Hashable {}
extension ByronBlockHeader.LwDlgSig: Equatable, Hashable {}
extension ByronBlockHeader.BlockSignature: Equatable, Hashable {}
extension ByronBlockHeader.EBBHead: Equatable, Hashable {}
extension ByronBlockHeader.BFTHead: Equatable, Hashable {}
extension ByronBlockHeader: Equatable, Hashable {}

// MARK: - Serializable

extension ByronBlockHeader: Serializable {

    // MARK: CBORSerializable

    /// Decode from the 5-element Byron head array (shared by both EBB and BFT).
    ///
    /// The variant is detected by the structure of `consensusData` (element[3]):
    /// - 2-element list → EBB (`[epoch, [difficulty]]`)
    /// - ≥4-element list → BFT (`[slotId, issuer, [difficulty], signature]`)
    public init(from primitive: Primitive) throws {
        guard case .list(let headElements) = primitive, headElements.count >= 5 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader: expected ≥5-element array, got \(primitive)"
            )
        }
        guard case .list(let cons) = headElements[3] else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader: consensusData (element[3]) must be a list"
            )
        }

        if cons.count == 2 {
            // EBB: consensusData = [epoch, [difficulty]]
            let protocolMagic = UInt32(try Self.uintFrom(headElements[0]))
            let prevBlock = Self.bytesOrNil(headElements[1])
            let bodyProof = try Self.primitiveToData(headElements[2])
            let epoch = try Self.uintFrom(cons[0])
            let difficulty = try Self.difficultyFrom(cons[1])
            self = .ebb(
                EBBHead(
                    protocolMagic: protocolMagic,
                    prevBlock: prevBlock,
                    bodyProof: bodyProof,
                    epoch: epoch,
                    difficulty: difficulty,
                    absoluteSlot: nil
                ))
        } else {
            // BFT: consensusData = [slotId, issuer, [difficulty], signature]
            guard cons.count >= 4 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BFT: consensusData needs ≥4 elements, got \(cons.count)"
                )
            }
            let protocolMagic = UInt32(try Self.uintFrom(headElements[0]))
            let prevBlock = Self.bytesOrNil(headElements[1])
            let bodyProof = try Self.primitiveToData(headElements[2])

            guard case .list(let slotEl) = cons[0], slotEl.count >= 2 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BFT: slotId must be [epoch, slot]"
                )
            }
            let slotId = SlotId(
                epoch: try Self.uintFrom(slotEl[0]),
                slot: try Self.uintFrom(slotEl[1])
            )
            guard case .bytes(let issuerKey) = cons[1] else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BFT: issuer must be bytes"
                )
            }
            let difficulty = try Self.difficultyFrom(cons[2])
            let signature = try Self.parseBlockSig(cons[3])

            var blockVersion = BlockVersion.zero
            var softwareVersion = SoftwareVersion.unknown
            if case .list(let extra) = headElements[4], extra.count >= 2 {
                blockVersion = Self.parseBlockVer(extra[0])
                softwareVersion = Self.parseSoftVer(extra[1])
            }

            self = .bft(
                BFTHead(
                    protocolMagic: protocolMagic,
                    prevBlock: prevBlock,
                    bodyProof: bodyProof,
                    slotId: slotId,
                    issuerKey: issuerKey,
                    difficulty: difficulty,
                    signature: signature,
                    blockVersion: blockVersion,
                    softwareVersion: softwareVersion,
                    absoluteSlot: nil
                ))
        }
    }

    /// Encode to the 5-element Byron head CBOR array.
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .ebb(let ebb):
            return .list([
                .uint(UInt64(ebb.protocolMagic)),
                ebb.prevBlock.map { .bytes($0) } ?? .bytes(Data()),
                Self.dataToBodyProofPrimitive(ebb.bodyProof),
                .list([
                    .uint(ebb.epoch),
                    .list([.uint(ebb.difficulty)]),
                ]),
                .list([]),
            ])

        case .bft(let bft):
            let sigPrimitive = Self.encodeSig(bft.signature)
            return .list([
                .uint(UInt64(bft.protocolMagic)),
                bft.prevBlock.map { .bytes($0) } ?? .bytes(Data()),
                Self.dataToBodyProofPrimitive(bft.bodyProof),
                .list([
                    .list([.uint(bft.slotId.epoch), .uint(bft.slotId.slot)]),
                    .bytes(bft.issuerKey),
                    .list([.uint(bft.difficulty)]),
                    sigPrimitive,
                ]),
                .list([
                    .list([
                        .uint(UInt64(bft.blockVersion.major)),
                        .uint(UInt64(bft.blockVersion.minor)),
                        .uint(UInt64(bft.blockVersion.alt)),
                    ]),
                    .list([
                        .string(bft.softwareVersion.appName),
                        .uint(UInt64(bft.softwareVersion.number)),
                    ]),
                    .orderedDict([:]),  // attributes
                    .bytes(Data()),  // extraProof
                ]),
            ])
        }
    }

    // MARK: JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ByronBlockHeader {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("ByronBlockHeader.fromDict: expected dict")
        }
        guard let typeP = dict[.string("type")], case .string(let type_) = typeP else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader.fromDict: missing 'type' field")
        }

        switch type_ {
        case "ebb":
            guard let pmP = dict[.string("protocolMagic")],
                let epochP = dict[.string("epoch")],
                let diffP = dict[.string("difficulty")]
            else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader EBB: missing required fields")
            }
            let protocolMagic = UInt32(try uintFrom(pmP))
            let prevBlock: Data? = try hexDataOrNil(dict[.string("prevBlock")])
            let bodyProof: Data = (try? hexDataOrNil(dict[.string("bodyProof")])) ?? Data()
            let epoch = try uintFrom(epochP)
            let difficulty = try uintFrom(diffP)
            let absSlot: UInt64? = dict[.string("absoluteSlot")].flatMap { try? uintFrom($0) }
            return .ebb(
                EBBHead(
                    protocolMagic: protocolMagic,
                    prevBlock: prevBlock,
                    bodyProof: bodyProof,
                    epoch: epoch,
                    difficulty: difficulty,
                    absoluteSlot: absSlot
                ))

        case "bft":
            guard let pmP = dict[.string("protocolMagic")],
                let epochP = dict[.string("slotEpoch")],
                let slotP = dict[.string("slotInEpoch")],
                let ikP = dict[.string("issuerKey")],
                let diffP = dict[.string("difficulty")],
                let sigP = dict[.string("signature")]
            else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BFT: missing required fields")
            }
            let protocolMagic = UInt32(try uintFrom(pmP))
            let prevBlock: Data? = try hexDataOrNil(dict[.string("prevBlock")])
            let bodyProof: Data = (try? hexDataOrNil(dict[.string("bodyProof")])) ?? Data()
            let slotId = SlotId(epoch: try uintFrom(epochP), slot: try uintFrom(slotP))
            guard case .string(let ikHex) = ikP, let issuerKey = Data(hexString: ikHex) else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BFT: issuerKey must be hex string")
            }
            let difficulty = try uintFrom(diffP)
            let signature = try blockSigFromDict(sigP)
            let absSlot: UInt64? = dict[.string("absoluteSlot")].flatMap { try? uintFrom($0) }

            var blockVersion = BlockVersion.zero
            if let bvP = dict[.string("blockVersion")],
                case .orderedDict(let bvD) = bvP,
                let majP = bvD[.string("major")],
                let minP = bvD[.string("minor")],
                let altP = bvD[.string("alt")]
            {
                blockVersion = BlockVersion(
                    major: UInt16(try uintFrom(majP)),
                    minor: UInt16(try uintFrom(minP)),
                    alt: UInt8(try uintFrom(altP))
                )
            }
            var softwareVersion = SoftwareVersion.unknown
            if let svP = dict[.string("softwareVersion")],
                case .orderedDict(let svD) = svP,
                case .string(let appName) = svD[.string("appName")],
                let numP = svD[.string("number")]
            {
                softwareVersion = SoftwareVersion(
                    appName: appName, number: UInt32(try uintFrom(numP)))
            }

            return .bft(
                BFTHead(
                    protocolMagic: protocolMagic,
                    prevBlock: prevBlock,
                    bodyProof: bodyProof,
                    slotId: slotId,
                    issuerKey: issuerKey,
                    difficulty: difficulty,
                    signature: signature,
                    blockVersion: blockVersion,
                    softwareVersion: softwareVersion,
                    absoluteSlot: absSlot
                ))

        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader.fromDict: unknown type '\(type_)'")
        }
    }

    public func toDict() throws -> Primitive {
        switch self {
        case .ebb(let ebb):
            var dict = OrderedDictionary<Primitive, Primitive>()
            dict[.string("type")] = .string("ebb")
            dict[.string("protocolMagic")] = .uint(UInt64(ebb.protocolMagic))
            dict[.string("prevBlock")] = ebb.prevBlock.map { .string($0.toHex) } ?? .null
            dict[.string("bodyProof")] = .string(ebb.bodyProof.toHex)
            dict[.string("epoch")] = .uint(ebb.epoch)
            dict[.string("difficulty")] = .uint(ebb.difficulty)
            if let abs = ebb.absoluteSlot { dict[.string("absoluteSlot")] = .uint(abs) }
            return .orderedDict(dict)

        case .bft(let bft):
            var dict = OrderedDictionary<Primitive, Primitive>()
            dict[.string("type")] = .string("bft")
            dict[.string("protocolMagic")] = .uint(UInt64(bft.protocolMagic))
            dict[.string("prevBlock")] = bft.prevBlock.map { .string($0.toHex) } ?? .null
            dict[.string("bodyProof")] = .string(bft.bodyProof.toHex)
            dict[.string("slotEpoch")] = .uint(bft.slotId.epoch)
            dict[.string("slotInEpoch")] = .uint(bft.slotId.slot)
            dict[.string("issuerKey")] = .string(bft.issuerKey.toHex)
            dict[.string("difficulty")] = .uint(bft.difficulty)
            dict[.string("signature")] = sigToDict(bft.signature)

            var bvDict = OrderedDictionary<Primitive, Primitive>()
            bvDict[.string("major")] = .uint(UInt64(bft.blockVersion.major))
            bvDict[.string("minor")] = .uint(UInt64(bft.blockVersion.minor))
            bvDict[.string("alt")] = .uint(UInt64(bft.blockVersion.alt))
            dict[.string("blockVersion")] = .orderedDict(bvDict)

            var svDict = OrderedDictionary<Primitive, Primitive>()
            svDict[.string("appName")] = .string(bft.softwareVersion.appName)
            svDict[.string("number")] = .uint(UInt64(bft.softwareVersion.number))
            dict[.string("softwareVersion")] = .orderedDict(svDict)

            if let abs = bft.absoluteSlot { dict[.string("absoluteSlot")] = .uint(abs) }
            return .orderedDict(dict)
        }
    }

    // MARK: - Hashable

    public func hash() -> Data {
        return try! Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: BLOCK_HEADER_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }

    // MARK: Private helpers

    private static func uintFrom(_ p: Primitive) throws -> UInt64 {
        switch p {
        case .uint(let v): return UInt64(v)
        case .int(let v): return UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("ByronBlockHeader: expected uint, got \(p)")
        }
    }

    private static func bytesOrNil(_ p: Primitive) -> Data? {
        guard case .bytes(let d) = p, !d.isEmpty else { return nil }
        return d
    }

    private static func bytesOrEmpty(_ p: Primitive) -> Data {
        guard case .bytes(let d) = p else { return Data() }
        return d
    }

    /// Re-encodes `p` to CBOR bytes if it is not already a `.bytes` primitive.
    /// `blockproof` on the wire is a list structure, not raw bytes.
    private static func primitiveToData(_ p: Primitive) throws -> Data {
        if case .bytes(let d) = p { return d }
        return try CBOREncoder().encode(p)
    }

    /// Decodes CBOR bytes back to the original `Primitive` for wire output.
    /// Falls back to `.list([])` for empty data and `.bytes` for opaque blobs.
    private static func dataToBodyProofPrimitive(_ d: Data) -> Primitive {
        if d.isEmpty { return .list([]) }
        return (try? CBORDecoder().decode(Primitive.self, from: d)) ?? .bytes(d)
    }

    private static func difficultyFrom(_ p: Primitive) throws -> UInt64 {
        guard case .list(let elements) = p, let first = elements.first else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader: chainDifficulty must be [uint]"
            )
        }
        return try uintFrom(first)
    }

    private static func hexDataOrNil(_ p: Primitive?) throws -> Data? {
        guard let p = p else { return nil }
        switch p {
        case .null: return nil
        case .string(let hex): return Data(hexString: hex)
        default: return nil
        }
    }

    private static func parseBlockSig(_ p: Primitive) throws -> BlockSignature {
        guard case .list(let elements) = p, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader BlockSignature: expected [kind, payload]"
            )
        }
        let kind = try uintFrom(elements[0])
        switch kind {
        case 0:
            guard case .bytes(let sig) = elements[1] else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader BlockSignature regular: payload must be bytes"
                )
            }
            return .regular(sig)
        case 1:
            return .lightweightDelegation(try parseLwDlgSig(elements[1]))
        case 2:
            return .delegation(try parseDlgSig(elements[1]))
        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader BlockSignature: unknown kind \(kind)"
            )
        }
    }

    private static func parseDlgSig(_ p: Primitive) throws -> DlgSig {
        guard case .list(let elements) = p, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader DlgSig: expected [dlg, signature]")
        }
        let dlg = try parseDlg(elements[0])
        guard case .bytes(let sig) = elements[1] else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader DlgSig: signature must be bytes")
        }
        return DlgSig(delegation: dlg, signature: sig)
    }

    private static func parseDlg(_ p: Primitive) throws -> Dlg {
        guard case .list(let elements) = p, elements.count >= 4 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader Dlg: expected [epoch, issuer, delegate, certificate]"
            )
        }
        guard case .bytes(let issuer) = elements[1],
            case .bytes(let delegate) = elements[2],
            case .bytes(let cert) = elements[3]
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader Dlg: issuer, delegate, certificate must be bytes"
            )
        }
        return Dlg(
            epoch: try uintFrom(elements[0]), issuer: issuer, delegate: delegate, certificate: cert)
    }

    private static func parseLwDlgSig(_ p: Primitive) throws -> LwDlgSig {
        guard case .list(let elements) = p, elements.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlgSig: expected [lwdlg, signature]")
        }
        let lwdlg = try parseLwDlg(elements[0])
        guard case .bytes(let sig) = elements[1] else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlgSig: signature must be bytes")
        }
        return LwDlgSig(delegation: lwdlg, signature: sig)
    }

    private static func parseLwDlg(_ p: Primitive) throws -> LwDlg {
        guard case .list(let elements) = p, elements.count >= 4 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlg: expected [[epochFrom, epochTo], issuer, delegate, certificate]"
            )
        }
        guard case .list(let epochRange) = elements[0], epochRange.count >= 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlg: epochRange must be [from, to]")
        }
        guard case .bytes(let issuer) = elements[1],
            case .bytes(let delegate) = elements[2],
            case .bytes(let cert) = elements[3]
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlg: issuer, delegate, certificate must be bytes"
            )
        }
        return LwDlg(
            epochFrom: try uintFrom(epochRange[0]),
            epochTo: try uintFrom(epochRange[1]),
            issuer: issuer, delegate: delegate, certificate: cert
        )
    }

    private static func parseBlockVer(_ p: Primitive) -> BlockVersion {
        guard case .list(let bv) = p, bv.count >= 3,
            let maj = try? uintFrom(bv[0]),
            let min = try? uintFrom(bv[1]),
            let alt = try? uintFrom(bv[2])
        else { return .zero }
        return BlockVersion(major: UInt16(maj), minor: UInt16(min), alt: UInt8(alt))
    }

    private static func parseSoftVer(_ p: Primitive) -> SoftwareVersion {
        guard case .list(let sv) = p, sv.count >= 2,
            case .string(let appName) = sv[0],
            let num = try? uintFrom(sv[1])
        else { return .unknown }
        return SoftwareVersion(appName: appName, number: UInt32(num))
    }

    // MARK: Encoding helpers

    private static func encodeSig(_ sig: BlockSignature) -> Primitive {
        switch sig {
        case .regular(let bytes):
            return .list([.uint(0), .bytes(bytes)])
        case .lightweightDelegation(let lwdlg):
            return .list([.uint(1), encodeLwDlgSig(lwdlg)])
        case .delegation(let dlg):
            return .list([.uint(2), encodeDlgSig(dlg)])
        }
    }

    private static func encodeDlgSig(_ d: DlgSig) -> Primitive {
        .list([encodeDlg(d.delegation), .bytes(d.signature)])
    }

    private static func encodeDlg(_ d: Dlg) -> Primitive {
        .list([.uint(d.epoch), .bytes(d.issuer), .bytes(d.delegate), .bytes(d.certificate)])
    }

    private static func encodeLwDlgSig(_ l: LwDlgSig) -> Primitive {
        .list([encodeLwDlg(l.delegation), .bytes(l.signature)])
    }

    private static func encodeLwDlg(_ l: LwDlg) -> Primitive {
        .list([
            .list([.uint(l.epochFrom), .uint(l.epochTo)]),
            .bytes(l.issuer), .bytes(l.delegate), .bytes(l.certificate),
        ])
    }

    // MARK: JSON signature helpers

    private static func blockSigFromDict(_ p: Primitive) throws -> BlockSignature {
        guard case .orderedDict(let dict) = p,
            let typeP = dict[.string("type")],
            case .string(let type_) = typeP
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader: signature must be a dict with 'type'")
        }
        switch type_ {
        case "regular":
            guard let sigP = dict[.string("signature")],
                case .string(let hex) = sigP,
                let sig = Data(hexString: hex)
            else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlockHeader regular sig: missing/invalid signature")
            }
            return .regular(sig)
        case "lightweightDelegation":
            guard let dlgP = dict[.string("delegation")],
                let sigP = dict[.string("signature")],
                case .string(let sigHex) = sigP,
                let sig = Data(hexString: sigHex)
            else {
                throw CardanoCoreError.deserializeError("ByronBlockHeader lwdlg: missing fields")
            }
            return .lightweightDelegation(
                LwDlgSig(delegation: try lwDlgFromDict(dlgP), signature: sig))
        case "delegation":
            guard let dlgP = dict[.string("delegation")],
                let sigP = dict[.string("signature")],
                case .string(let sigHex) = sigP,
                let sig = Data(hexString: sigHex)
            else {
                throw CardanoCoreError.deserializeError("ByronBlockHeader dlg: missing fields")
            }
            return .delegation(DlgSig(delegation: try dlgFromDict(dlgP), signature: sig))
        default:
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader: unknown signature type '\(type_)'")
        }
    }

    private static func dlgFromDict(_ p: Primitive) throws -> Dlg {
        guard case .orderedDict(let dict) = p,
            let epochP = dict[.string("epoch")],
            case .string(let issuerHex) = dict[.string("issuer")] ?? .null,
            case .string(let delegateHex) = dict[.string("delegate")] ?? .null,
            case .string(let certHex) = dict[.string("certificate")] ?? .null,
            let issuer = Data(hexString: issuerHex),
            let delegate = Data(hexString: delegateHex),
            let cert = Data(hexString: certHex)
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader Dlg dict: missing/invalid fields")
        }
        return Dlg(
            epoch: try uintFrom(epochP), issuer: issuer, delegate: delegate, certificate: cert)
    }

    private static func lwDlgFromDict(_ p: Primitive) throws -> LwDlg {
        guard case .orderedDict(let dict) = p,
            let fromP = dict[.string("epochFrom")],
            let toP = dict[.string("epochTo")],
            case .string(let issuerHex) = dict[.string("issuer")] ?? .null,
            case .string(let delegateHex) = dict[.string("delegate")] ?? .null,
            case .string(let certHex) = dict[.string("certificate")] ?? .null,
            let issuer = Data(hexString: issuerHex),
            let delegate = Data(hexString: delegateHex),
            let cert = Data(hexString: certHex)
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader LwDlg dict: missing/invalid fields")
        }
        return LwDlg(
            epochFrom: try uintFrom(fromP), epochTo: try uintFrom(toP),
            issuer: issuer, delegate: delegate, certificate: cert
        )
    }

    private func sigToDict(_ sig: BlockSignature) -> Primitive {
        switch sig {
        case .regular(let bytes):
            var d = OrderedDictionary<Primitive, Primitive>()
            d[.string("type")] = .string("regular")
            d[.string("signature")] = .string(bytes.toHex)
            return .orderedDict(d)
        case .lightweightDelegation(let l):
            var d = OrderedDictionary<Primitive, Primitive>()
            d[.string("type")] = .string("lightweightDelegation")
            d[.string("delegation")] = lwDlgToDict(l.delegation)
            d[.string("signature")] = .string(l.signature.toHex)
            return .orderedDict(d)
        case .delegation(let dl):
            var d = OrderedDictionary<Primitive, Primitive>()
            d[.string("type")] = .string("delegation")
            d[.string("delegation")] = dlgToDict(dl.delegation)
            d[.string("signature")] = .string(dl.signature.toHex)
            return .orderedDict(d)
        }
    }

    private func dlgToDict(_ dlg: Dlg) -> Primitive {
        var d = OrderedDictionary<Primitive, Primitive>()
        d[.string("epoch")] = .uint(dlg.epoch)
        d[.string("issuer")] = .string(dlg.issuer.toHex)
        d[.string("delegate")] = .string(dlg.delegate.toHex)
        d[.string("certificate")] = .string(dlg.certificate.toHex)
        return .orderedDict(d)
    }

    private func lwDlgToDict(_ lwdlg: LwDlg) -> Primitive {
        var d = OrderedDictionary<Primitive, Primitive>()
        d[.string("epochFrom")] = .uint(lwdlg.epochFrom)
        d[.string("epochTo")] = .uint(lwdlg.epochTo)
        d[.string("issuer")] = .string(lwdlg.issuer.toHex)
        d[.string("delegate")] = .string(lwdlg.delegate.toHex)
        d[.string("certificate")] = .string(lwdlg.certificate.toHex)
        return .orderedDict(d)
    }
}
