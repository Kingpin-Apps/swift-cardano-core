import Foundation
import OrderedCollections
import CBORCodable

/// A Byron era block header — either an Epoch Boundary Block header or a
/// regular block header.
///
/// Derived from the Byron CDDL specification:
/// https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/byron/ledger/impl/cddl-spec/byron.cddl
///
/// Both header types are 5-element arrays but differ in `bodyProof`,
/// `consensusData` and `extraData`:
///
/// ```
/// ebbhead   = [protocolMagic, prevBlock, bodyProof : hash, consensusData : ebbcons, extraData : [attributes]]
///   ebbcons   = [epochid, difficulty]
///
/// blockhead = [protocolMagic, prevBlock, bodyProof : blockproof, consensusData : blockcons, extraData : blockheadex]
///   blockcons   = [slotid, pubkey, difficulty, blocksig]
///   blockheadex = [blockVersion, softwareVersion, attributes, extraProof]
/// ```
///
/// The discriminant (0 = EBB, 1 = regular) comes from the outer block wrapper
/// (`block = [0, ebblock] / [1, mainblock]`) or from the NtN framing
/// (`[[0|1, blockSize], #6.24(head)]`). A decoded header keeps the bytes it
/// was read from, and its ``hash()`` — the block hash — is taken over them.
public enum ByronBlockHeader: Sendable {
    case ebb(EBBHead)
    case bft(BFTHead)

    // MARK: - EBBHead

    /// The header of an Epoch Boundary Block.
    ///
    /// ```
    /// ebbhead = [ protocolMagic : u32
    ///           , prevBlock      : blockid       ; blake2b-256
    ///           , bodyProof      : hash          ; blake2b-256 of the body
    ///           , consensusData  : ebbcons       ; [epochid, difficulty]
    ///           , extraData      : [attributes]
    ///           ]
    /// difficulty = [u64]
    /// ```
    public struct EBBHead: Sendable, Equatable, Hashable {
        /// Network protocol magic.
        public var protocolMagic: UInt32 { didSet { _original.data = nil } }
        /// Hash of the previous block; the genesis hash for the first EBB.
        public var prevBlock: Data { didSet { _original.data = nil } }
        /// Blake2b-256 hash of the block body.
        public var bodyProof: Data { didSet { _original.data = nil } }
        /// Epoch number from `ebbcons[0]`.
        public var epoch: UInt64 { didSet { _original.data = nil } }
        /// Chain difficulty (block height) from `ebbcons[1] = [u64]`.
        public var difficulty: UInt64 { didSet { _original.data = nil } }
        /// The attributes in `extraData = [attributes]`.
        public var attributes: ByronAttributes { didSet { _original.data = nil } }

        var _original = ByronOriginalBytes()

        /// The exact bytes this header was decoded from, while it is unchanged.
        public internal(set) var originalCBOR: Data? {
            get { _original.data }
            set { _original.data = newValue }
        }

        public init(
            protocolMagic: UInt32,
            prevBlock: Data,
            bodyProof: Data,
            epoch: UInt64,
            difficulty: UInt64,
            attributes: ByronAttributes = .empty
        ) {
            self.protocolMagic = protocolMagic
            self.prevBlock = prevBlock
            self.bodyProof = bodyProof
            self.epoch = epoch
            self.difficulty = difficulty
            self.attributes = attributes
        }

        /// The block hash: Blake2b-256 of `[0, ebbhead]`.
        public func hash() -> Data {
            ByronHash.header(discriminant: 0, headerCBOR: try! toCBORData())
        }

        /// The bytes this header was decoded from while it is unchanged,
        /// otherwise a fresh encoding.
        public func toCBORData() throws -> Data {
            try originalCBOR ?? freshCBOR()
        }

        func freshCBOR() throws -> Data {
            var writer = ByronCBORWriter()
            writer.array(5)
            writer.uint(protocolMagic)
            writer.bytes(prevBlock)
            writer.bytes(bodyProof)
            writer.array(2)
            writer.uint(epoch)
            ByronBlockHeader.writeDifficulty(difficulty, to: &writer)
            writer.array(1)
            writer.raw(try attributes.toCBORData())
            return writer.data
        }

        static func decode(_ item: ByronCBORItem) throws -> EBBHead {
            let elements = try item.array("ebbhead", count: 5)
            let consensus = try elements[3].array("ebbhead consensusData", count: 2)
            let extra = try elements[4].array("ebbhead extraData", count: 1)
            var head = EBBHead(
                protocolMagic: try elements[0].uint("ebbhead protocolMagic", as: UInt32.self),
                prevBlock: try elements[1].byteString("ebbhead prevBlock", count: 32),
                bodyProof: try elements[2].byteString("ebbhead bodyProof", count: 32),
                epoch: try consensus[0].uint("ebbhead epoch"),
                difficulty: try ByronBlockHeader.decodeDifficulty(consensus[1]),
                attributes: try ByronAttributes.decode(extra[0], "ebbhead attributes")
            )
            head.originalCBOR = item.bytes
            return head
        }
    }

    // MARK: - BFTHead

    /// The header of a regular Byron block.
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
    /// blockheadex = [blockVersion : bver, softwareVersion : [text, u32], attributes, extraProof : hash]
    /// ```
    public struct BFTHead: Sendable, Equatable, Hashable {
        /// Network protocol magic.
        public var protocolMagic: UInt32 { didSet { _original.data = nil } }
        /// Hash of the previous block.
        public var prevBlock: Data { didSet { _original.data = nil } }
        /// Proofs committing to each payload of the block body.
        public var bodyProof: BlockProof { didSet { _original.data = nil } }
        /// Slot identifier — epoch number and slot within epoch.
        public var slotId: SlotId { didSet { _original.data = nil } }
        /// Block issuer public key (`pubkey` in `blockcons`) — the hot key
        /// that signed the block, normally a 64-byte extended Ed25519 key.
        public var issuerKey: Data { didSet { _original.data = nil } }
        /// Chain difficulty (block height).
        public var difficulty: UInt64 { didSet { _original.data = nil } }
        /// Block signature, carrying the delegation the issuer signs under.
        public var signature: BlockSignature { didSet { _original.data = nil } }
        /// Protocol version from `blockheadex.blockVersion`.
        public var blockVersion: BlockVersion { didSet { _original.data = nil } }
        /// Software version from `blockheadex.softwareVersion`.
        public var softwareVersion: SoftwareVersion { didSet { _original.data = nil } }
        /// Attributes from `blockheadex.attributes`.
        public var attributes: ByronAttributes { didSet { _original.data = nil } }
        /// Blake2b-256 hash of the block's extra body data.
        public var extraProof: Data { didSet { _original.data = nil } }

        var _original = ByronOriginalBytes()

        /// The exact bytes this header was decoded from, while it is unchanged.
        public internal(set) var originalCBOR: Data? {
            get { _original.data }
            set { _original.data = newValue }
        }

        public init(
            protocolMagic: UInt32,
            prevBlock: Data,
            bodyProof: BlockProof,
            slotId: SlotId,
            issuerKey: Data,
            difficulty: UInt64,
            signature: BlockSignature,
            blockVersion: BlockVersion,
            softwareVersion: SoftwareVersion,
            attributes: ByronAttributes = .empty,
            extraProof: Data
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
            self.attributes = attributes
            self.extraProof = extraProof
        }

        /// The block hash: Blake2b-256 of `[1, blockhead]`.
        public func hash() -> Data {
            ByronHash.header(discriminant: 1, headerCBOR: try! toCBORData())
        }

        /// The absolute slot, given the number of slots in a Byron epoch
        /// (21600 on mainnet: ten times the security parameter k = 2160).
        public func absoluteSlot(epochLength: UInt64 = ByronBlockHeader.mainnetEpochLength) -> UInt64 {
            slotId.epoch * epochLength + slotId.slot
        }

        /// The bytes this header was decoded from while it is unchanged,
        /// otherwise a fresh encoding.
        public func toCBORData() throws -> Data {
            try originalCBOR ?? freshCBOR()
        }

        func freshCBOR() throws -> Data {
            var writer = ByronCBORWriter()
            writer.array(5)
            writer.uint(protocolMagic)
            writer.bytes(prevBlock)
            bodyProof.write(to: &writer)
            writer.array(4)
            slotId.write(to: &writer)
            writer.bytes(issuerKey)
            ByronBlockHeader.writeDifficulty(difficulty, to: &writer)
            signature.write(to: &writer)
            writer.array(4)
            blockVersion.write(to: &writer)
            softwareVersion.write(to: &writer)
            writer.raw(try attributes.toCBORData())
            writer.bytes(extraProof)
            return writer.data
        }

        static func decode(_ item: ByronCBORItem) throws -> BFTHead {
            let elements = try item.array("blockhead", count: 5)
            let consensus = try elements[3].array("blockhead consensusData", count: 4)
            let extra = try elements[4].array("blockhead extraData", count: 4)
            var head = BFTHead(
                protocolMagic: try elements[0].uint("blockhead protocolMagic", as: UInt32.self),
                prevBlock: try elements[1].byteString("blockhead prevBlock", count: 32),
                bodyProof: try BlockProof.decode(elements[2]),
                slotId: try SlotId.decode(consensus[0]),
                issuerKey: try consensus[1].byteString("blockhead issuer"),
                difficulty: try ByronBlockHeader.decodeDifficulty(consensus[2]),
                signature: try BlockSignature.decode(consensus[3]),
                blockVersion: try BlockVersion.decode(extra[0]),
                softwareVersion: try SoftwareVersion.decode(extra[1]),
                attributes: try ByronAttributes.decode(extra[2], "blockhead attributes"),
                extraProof: try extra[3].byteString("blockhead extraProof", count: 32)
            )
            head.originalCBOR = item.bytes
            return head
        }
    }

    // MARK: - Body proof

    /// Proofs of the four payloads of a regular block's body.
    ///
    /// ```
    /// blockproof = [txProof : txproof, sscProof : sscproof, dlgProof : hash, updProof : hash]
    /// ```
    public struct BlockProof: Sendable, Equatable, Hashable {
        /// Proof of the transaction payload.
        public let txProof: TxProof
        /// Proof of the shared seed computation payload.
        public let sscProof: SscProof
        /// Blake2b-256 hash of the delegation payload.
        public let dlgProof: Data
        /// Blake2b-256 hash of the update payload.
        public let updProof: Data

        public init(txProof: TxProof, sscProof: SscProof, dlgProof: Data, updProof: Data) {
            self.txProof = txProof
            self.sscProof = sscProof
            self.dlgProof = dlgProof
            self.updProof = updProof
        }

        static func decode(_ item: ByronCBORItem) throws -> BlockProof {
            let elements = try item.array("blockproof", count: 4)
            return BlockProof(
                txProof: try TxProof.decode(elements[0]),
                sscProof: try SscProof.decode(elements[1]),
                dlgProof: try elements[2].byteString("blockproof dlgProof", count: 32),
                updProof: try elements[3].byteString("blockproof updProof", count: 32)
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(4)
            txProof.write(to: &writer)
            sscProof.write(to: &writer)
            writer.bytes(dlgProof)
            writer.bytes(updProof)
        }
    }

    /// Proof of the transaction payload.
    ///
    /// `txproof = [u32, hash, hash]` — the number of transactions, the Merkle
    /// root of the transactions, and the hash of the list of witness lists.
    public struct TxProof: Sendable, Equatable, Hashable {
        public let transactionCount: UInt32
        public let merkleRoot: Data
        public let witnessesHash: Data

        public init(transactionCount: UInt32, merkleRoot: Data, witnessesHash: Data) {
            self.transactionCount = transactionCount
            self.merkleRoot = merkleRoot
            self.witnessesHash = witnessesHash
        }

        static func decode(_ item: ByronCBORItem) throws -> TxProof {
            let elements = try item.array("txproof", count: 3)
            return TxProof(
                transactionCount: try elements[0].uint("txproof count", as: UInt32.self),
                merkleRoot: try elements[1].byteString("txproof merkle root", count: 32),
                witnessesHash: try elements[2].byteString("txproof witnesses hash", count: 32)
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(3)
            writer.uint(transactionCount)
            writer.bytes(merkleRoot)
            writer.bytes(witnessesHash)
        }
    }

    /// Proof of the shared seed computation payload, one case per
    /// ``ByronSscPayload`` case.
    ///
    /// ```
    /// sscproof = [0, hash, hash] / [1, hash, hash] / [2, hash, hash] / [3, hash]
    /// ```
    public enum SscProof: Sendable, Equatable, Hashable {
        /// `[0, commitmentsHash, certificatesHash]`
        case commitments(payloadHash: Data, certificatesHash: Data)
        /// `[1, openingsHash, certificatesHash]`
        case openings(payloadHash: Data, certificatesHash: Data)
        /// `[2, sharesHash, certificatesHash]`
        case shares(payloadHash: Data, certificatesHash: Data)
        /// `[3, certificatesHash]`
        case certificates(certificatesHash: Data)

        static func decode(_ item: ByronCBORItem) throws -> SscProof {
            let elements = try item.array("sscproof")
            guard let first = elements.first else {
                throw CardanoCoreError.deserializeError("sscproof: empty array")
            }
            let kind = try first.uint("sscproof kind")
            if kind == 3 {
                guard elements.count == 2 else {
                    throw CardanoCoreError.deserializeError("sscproof [3, hash]: expected 2 elements")
                }
                return .certificates(
                    certificatesHash: try elements[1].byteString("sscproof hash", count: 32))
            }
            guard elements.count == 3 else {
                throw CardanoCoreError.deserializeError("sscproof [\(kind), hash, hash]: expected 3 elements")
            }
            let payloadHash = try elements[1].byteString("sscproof hash", count: 32)
            let certificatesHash = try elements[2].byteString("sscproof hash", count: 32)
            switch kind {
            case 0: return .commitments(payloadHash: payloadHash, certificatesHash: certificatesHash)
            case 1: return .openings(payloadHash: payloadHash, certificatesHash: certificatesHash)
            case 2: return .shares(payloadHash: payloadHash, certificatesHash: certificatesHash)
            default:
                throw CardanoCoreError.deserializeError("sscproof: unknown kind \(kind)")
            }
        }

        func write(to writer: inout ByronCBORWriter) {
            switch self {
            case .commitments(let payloadHash, let certificatesHash),
                .openings(let payloadHash, let certificatesHash),
                .shares(let payloadHash, let certificatesHash):
                writer.array(3)
                writer.uint(kind)
                writer.bytes(payloadHash)
                writer.bytes(certificatesHash)
            case .certificates(let certificatesHash):
                writer.array(2)
                writer.uint(3 as UInt8)
                writer.bytes(certificatesHash)
            }
        }

        private var kind: UInt8 {
            switch self {
            case .commitments: return 0
            case .openings: return 1
            case .shares: return 2
            case .certificates: return 3
            }
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

        static func decode(_ item: ByronCBORItem) throws -> SlotId {
            let elements = try item.array("slotid", count: 2)
            return SlotId(
                epoch: try elements[0].uint("slotid epoch"),
                slot: try elements[1].uint("slotid slot")
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(2)
            writer.uint(epoch)
            writer.uint(slot)
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

        static func decode(_ item: ByronCBORItem) throws -> BlockVersion {
            let elements = try item.array("bver", count: 3)
            return BlockVersion(
                major: try elements[0].uint("bver major", as: UInt16.self),
                minor: try elements[1].uint("bver minor", as: UInt16.self),
                alt: try elements[2].uint("bver alt", as: UInt8.self)
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(3)
            writer.uint(major)
            writer.uint(minor)
            writer.uint(alt)
        }
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

        static func decode(_ item: ByronCBORItem) throws -> SoftwareVersion {
            let elements = try item.array("softwareVersion", count: 2)
            return SoftwareVersion(
                appName: try elements[0].text("softwareVersion appName"),
                number: try elements[1].uint("softwareVersion number", as: UInt32.self)
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(2)
            writer.text(appName)
            writer.uint(number)
        }
    }

    /// Byron block signature.
    ///
    /// ```
    /// blocksig = [0, signature]    ; signed directly by the issuer
    ///          / [1, lwdlgsig]     ; lightweight delegation signature
    ///          / [2, dlgsig]       ; heavy delegation signature (used on mainnet)
    /// ```
    public enum BlockSignature: Sendable {
        /// Plain signature: `[0, signature]`
        case regular(Data)
        /// Lightweight (short-range) delegation: `[1, lwdlgsig]`
        case lightweightDelegation(LwDlgSig)
        /// Heavy delegation certificate: `[2, dlgsig]`
        case delegation(DlgSig)

        static func decode(_ item: ByronCBORItem) throws -> BlockSignature {
            let elements = try item.array("blocksig", count: 2)
            let kind = try elements[0].uint("blocksig kind")
            switch kind {
            case 0: return .regular(try elements[1].byteString("blocksig signature"))
            case 1: return .lightweightDelegation(try LwDlgSig.decode(elements[1]))
            case 2: return .delegation(try DlgSig.decode(elements[1]))
            default:
                throw CardanoCoreError.deserializeError("blocksig: unknown kind \(kind)")
            }
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(2)
            switch self {
            case .regular(let signature):
                writer.uint(0 as UInt8)
                writer.bytes(signature)
            case .lightweightDelegation(let signature):
                writer.uint(1 as UInt8)
                signature.write(to: &writer)
            case .delegation(let signature):
                writer.uint(2 as UInt8)
                signature.write(to: &writer)
            }
        }
    }

    /// Heavy delegation signature: `dlgsig = [dlg, signature]`
    public struct DlgSig: Sendable {
        public let delegation: Dlg
        public let signature: Data

        public init(delegation: Dlg, signature: Data) {
            self.delegation = delegation
            self.signature = signature
        }

        static func decode(_ item: ByronCBORItem) throws -> DlgSig {
            let elements = try item.array("dlgsig", count: 2)
            return DlgSig(
                delegation: try Dlg.decode(elements[0]),
                signature: try elements[1].byteString("dlgsig signature")
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(2)
            delegation.write(to: &writer)
            writer.bytes(signature)
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

        static func decode(_ item: ByronCBORItem) throws -> LwDlgSig {
            let elements = try item.array("lwdlgsig", count: 2)
            return LwDlgSig(
                delegation: try LwDlg.decode(elements[0]),
                signature: try elements[1].byteString("lwdlgsig signature")
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(2)
            delegation.write(to: &writer)
            writer.bytes(signature)
        }
    }

    /// Heavy delegation certificate, as carried in a block signature and in a
    /// block body's delegation payload.
    ///
    /// ```
    /// dlg = [epoch : epochid, issuer : pubkey, delegate : pubkey, certificate : signature]
    /// ```
    public struct Dlg: Sendable {
        /// Epoch the delegation is valid from.
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

        static func decode(_ item: ByronCBORItem) throws -> Dlg {
            let elements = try item.array("dlg", count: 4)
            return Dlg(
                epoch: try elements[0].uint("dlg epoch"),
                issuer: try elements[1].byteString("dlg issuer"),
                delegate: try elements[2].byteString("dlg delegate"),
                certificate: try elements[3].byteString("dlg certificate")
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(4)
            writer.uint(epoch)
            writer.bytes(issuer)
            writer.bytes(delegate)
            writer.bytes(certificate)
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

        static func decode(_ item: ByronCBORItem) throws -> LwDlg {
            let elements = try item.array("lwdlg", count: 4)
            let range = try elements[0].array("lwdlg epochRange", count: 2)
            return LwDlg(
                epochFrom: try range[0].uint("lwdlg epochRange"),
                epochTo: try range[1].uint("lwdlg epochRange"),
                issuer: try elements[1].byteString("lwdlg issuer"),
                delegate: try elements[2].byteString("lwdlg delegate"),
                certificate: try elements[3].byteString("lwdlg certificate")
            )
        }

        func write(to writer: inout ByronCBORWriter) {
            writer.array(4)
            writer.array(2)
            writer.uint(epochFrom)
            writer.uint(epochTo)
            writer.bytes(issuer)
            writer.bytes(delegate)
            writer.bytes(certificate)
        }
    }

    // MARK: - Convenience accessors

    /// Slots in a mainnet Byron epoch: 10 × k, with k = 2160.
    public static let mainnetEpochLength: UInt64 = 21600

    /// The block discriminant: 0 for an EBB, 1 for a regular block.
    public var discriminant: UInt8 {
        switch self {
        case .ebb: return 0
        case .bft: return 1
        }
    }

    /// Network protocol magic regardless of variant.
    public var protocolMagic: UInt32 {
        switch self {
        case .ebb(let h): return h.protocolMagic
        case .bft(let h): return h.protocolMagic
        }
    }

    /// Previous block hash regardless of variant.
    public var prevBlock: Data {
        switch self {
        case .ebb(let h): return h.prevBlock
        case .bft(let h): return h.prevBlock
        }
    }

    /// Epoch number regardless of variant.
    public var epoch: UInt64 {
        switch self {
        case .ebb(let h): return h.epoch
        case .bft(let h): return h.slotId.epoch
        }
    }

    /// Chain difficulty (block height) regardless of variant.
    public var difficulty: UInt64 {
        switch self {
        case .ebb(let h): return h.difficulty
        case .bft(let h): return h.difficulty
        }
    }

    /// The absolute slot, given the number of slots in a Byron epoch. An EBB
    /// shares the slot of the first block of its epoch.
    public func absoluteSlot(epochLength: UInt64 = mainnetEpochLength) -> UInt64 {
        switch self {
        case .ebb(let h): return h.epoch * epochLength
        case .bft(let h): return h.absoluteSlot(epochLength: epochLength)
        }
    }

    /// The exact bytes this header was decoded from, while it is unchanged.
    public var originalCBOR: Data? {
        switch self {
        case .ebb(let h): return h.originalCBOR
        case .bft(let h): return h.originalCBOR
        }
    }

    // MARK: - Decoding

    /// Decodes a header from its `ebbhead` or `blockhead` bytes, keeping them.
    ///
    /// Without the outer discriminant the variant is told by `consensusData`:
    /// a 2-element `ebbcons` for an EBB, a 4-element `blockcons` otherwise.
    public static func fromCBOR(data: Data) throws -> ByronBlockHeader {
        try decode(try ByronCBORItem(root: data, "Byron header"), discriminant: nil)
    }

    /// Decodes a header whose variant is given by `discriminant`, or told by
    /// its `consensusData` when it is `nil`.
    static func decode(_ item: ByronCBORItem, discriminant: UInt64?) throws -> ByronBlockHeader {
        let kind: UInt64
        if let discriminant {
            kind = discriminant
        } else {
            let elements = try item.array("Byron header", count: 5)
            kind = try elements[3].array("Byron header consensusData").count == 2 ? 0 : 1
        }
        switch kind {
        case 0: return .ebb(try EBBHead.decode(item))
        case 1: return .bft(try BFTHead.decode(item))
        default:
            throw CardanoCoreError.deserializeError("Byron header: unknown discriminant \(kind)")
        }
    }

    // MARK: - Shared helpers

    /// `difficulty = [u64]`
    static func decodeDifficulty(_ item: ByronCBORItem) throws -> UInt64 {
        try item.array("difficulty", count: 1)[0].uint("difficulty")
    }

    static func writeDifficulty(_ difficulty: UInt64, to writer: inout ByronCBORWriter) {
        writer.array(1)
        writer.uint(difficulty)
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
extension ByronBlockHeader: Equatable, Hashable {}

// MARK: - Serializable

extension ByronBlockHeader: Serializable {

    // MARK: CBORSerializable

    /// Decodes from the 5-element `ebbhead` or `blockhead` array.
    ///
    /// A primitive does not record how its items were written, so prefer
    /// ``fromCBOR(data:)`` where the header hash matters.
    public init(from primitive: Primitive) throws {
        self = try Self.fromCBOR(data: CBORSerialization.data(from: primitive.toCBOR()))
    }

    public func toPrimitive() throws -> Primitive {
        try Primitive.from(cbor: CBORSerialization.cbor(from: toCBORData()))
    }

    /// The bytes this header was decoded from while it is unchanged,
    /// otherwise a fresh encoding.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        switch self {
        case .ebb(let h): return try h.toCBORData()
        case .bft(let h): return try h.toCBORData()
        }
    }

    // MARK: JSONSerializable

    /// Decodes from the dictionary ``toDict()`` writes, using its `cbor` field;
    /// the other fields are a summary for reading.
    public static func fromDict(_ primitive: Primitive) throws -> ByronBlockHeader {
        guard case .orderedDict(let dict) = primitive,
            case .string(let hex) = dict[.string("cbor")] ?? .null,
            let data = Data(hexString: hex)
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader.fromDict: expected a dict with a 'cbor' hex string")
        }
        let header = try fromCBOR(data: data)
        if case .string(let type_) = dict[.string("type")] ?? .null,
            type_ != (header.discriminant == 0 ? "ebb" : "bft")
        {
            throw CardanoCoreError.deserializeError(
                "ByronBlockHeader.fromDict: 'type' \(type_) does not match the header")
        }
        return header
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(discriminant == 0 ? "ebb" : "bft")
        dict[.string("hash")] = .string(hash().toHex)
        dict[.string("protocolMagic")] = .uint(UInt64(protocolMagic))
        dict[.string("prevBlock")] = .string(prevBlock.toHex)
        dict[.string("epoch")] = .uint(epoch)
        if case .bft(let h) = self {
            dict[.string("slotInEpoch")] = .uint(h.slotId.slot)
            dict[.string("issuerKey")] = .string(h.issuerKey.toHex)
        }
        dict[.string("difficulty")] = .uint(difficulty)
        dict[.string("cbor")] = .string(try toCBORData().toHex)
        return .orderedDict(dict)
    }

    // MARK: - Hashing

    /// The block hash: Blake2b-256 of `[discriminant, header]`.
    public func hash() -> Data {
        switch self {
        case .ebb(let h): return h.hash()
        case .bft(let h): return h.hash()
        }
    }
}
