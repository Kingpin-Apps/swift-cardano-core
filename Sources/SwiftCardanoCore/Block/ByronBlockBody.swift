import Foundation
import OrderedCollections

// MARK: - ByronBlockBody

/// The body of a regular Byron block.
///
/// ```
/// blockbody = [ txPayload  : [* [tx, [* twit]]]
///             , sscPayload : ssc
///             , dlgPayload : [* dlg]
///             , updPayload : up
///             ]
/// ```
///
/// A decoded body keeps the bytes it was read from, and so does each of its
/// transactions, so a change to one part re-encodes that part alone.
public struct ByronBlockBody: Sendable, Equatable, Hashable {
    /// The transactions with their witnesses.
    public var transactions: [ByronTransactionAux] { didSet { _original.data = nil } }
    /// The shared seed computation payload.
    public var sscPayload: ByronSscPayload { didSet { _original.data = nil } }
    /// Heavy delegation certificates.
    public var delegationPayload: [ByronBlockHeader.Dlg] { didSet { _original.data = nil } }
    /// The update proposal and votes.
    public var updatePayload: ByronUpdatePayload { didSet { _original.data = nil } }

    var _original = ByronOriginalBytes()

    /// The exact bytes this body was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? {
        get { _original.data }
        set { _original.data = newValue }
    }

    public init(
        transactions: [ByronTransactionAux] = [],
        sscPayload: ByronSscPayload = .certificates([]),
        delegationPayload: [ByronBlockHeader.Dlg] = [],
        updatePayload: ByronUpdatePayload = ByronUpdatePayload()
    ) {
        self.transactions = transactions
        self.sscPayload = sscPayload
        self.delegationPayload = delegationPayload
        self.updatePayload = updatePayload
    }

    /// The bytes this body was decoded from while it is unchanged; otherwise
    /// a fresh encoding that keeps the bytes of each unchanged part.
    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.array(4)
        writer.beginIndefiniteArray()
        for transaction in transactions {
            writer.raw(try transaction.toCBORData())
        }
        writer.endIndefinite()
        writer.raw(try sscPayload.toCBORData())
        writer.indefiniteArray(delegationPayload) { $1.write(to: &$0) }
        writer.raw(try updatePayload.toCBORData())
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronBlockBody {
        let elements = try item.array("blockbody", count: 4)
        var body = ByronBlockBody(
            transactions: try elements[0].array("txPayload").map(ByronTransactionAux.decode),
            sscPayload: try ByronSscPayload.decode(elements[1]),
            delegationPayload: try elements[2].array("dlgPayload").map(ByronBlockHeader.Dlg.decode),
            updatePayload: try ByronUpdatePayload.decode(elements[3])
        )
        body.originalCBOR = item.bytes
        return body
    }
}

// MARK: - Shared seed computation

/// The shared seed computation (SSC) payload of a block body.
///
/// ```
/// ssc = [0, ssccomms, ssccerts]
///     / [1, sscopens, ssccerts]
///     / [2, sscshares, ssccerts]
///     / [3, ssccerts]
/// ```
///
/// - Note: The CDDL gives `sscshares = {* addressid => [addressid, [* vssdec]]}`,
///   but mainnet blocks carry a map of maps,
///   `{* addressid => {* addressid => [* vssdec]}}`, which is what this decodes.
public enum ByronSscPayload: Sendable, Equatable, Hashable {
    /// `[0, ssccomms, ssccerts]` — VSS commitments.
    case commitments([ByronSscCommitment], certificates: [ByronSscCertificate])
    /// `[1, sscopens, ssccerts]` — openings, by stakeholder id.
    case openings(OrderedDictionary<Data, Data>, certificates: [ByronSscCertificate])
    /// `[2, sscshares, ssccerts]` — decrypted shares, by the address id of
    /// the sender and then of the receiver.
    case shares(
        OrderedDictionary<Data, OrderedDictionary<Data, [Data]>>,
        certificates: [ByronSscCertificate])
    /// `[3, ssccerts]` — VSS certificates alone.
    case certificates([ByronSscCertificate])

    /// The VSS certificates, which every case carries.
    public var certificates: [ByronSscCertificate] {
        switch self {
        case .commitments(_, let certificates),
            .openings(_, let certificates),
            .shares(_, let certificates),
            .certificates(let certificates):
            return certificates
        }
    }

    public func toCBORData() throws -> Data {
        var writer = ByronCBORWriter()
        switch self {
        case .commitments(let commitments, let certificates):
            writer.array(3)
            writer.uint(0 as UInt8)
            writer.tag(258)
            writer.array(commitments.count)
            for commitment in commitments {
                writer.raw(try commitment.toCBORData())
            }
            Self.writeCertificates(certificates, to: &writer)
        case .openings(let openings, let certificates):
            writer.array(3)
            writer.uint(1 as UInt8)
            writer.map(openings.count)
            for (stakeholder, secret) in openings {
                writer.bytes(stakeholder)
                writer.bytes(secret)
            }
            Self.writeCertificates(certificates, to: &writer)
        case .shares(let shares, let certificates):
            writer.array(3)
            writer.uint(2 as UInt8)
            writer.map(shares.count)
            for (sender, received) in shares {
                writer.bytes(sender)
                writer.map(received.count)
                for (receiver, decrypted) in received {
                    writer.bytes(receiver)
                    writer.indefiniteArray(decrypted) { $0.bytes($1) }
                }
            }
            Self.writeCertificates(certificates, to: &writer)
        case .certificates(let certificates):
            writer.array(2)
            writer.uint(3 as UInt8)
            Self.writeCertificates(certificates, to: &writer)
        }
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronSscPayload {
        let elements = try item.array("ssc")
        guard let first = elements.first else {
            throw CardanoCoreError.deserializeError("ssc: empty array")
        }
        let kind = try first.uint("ssc kind")
        let expected = kind == 3 ? 2 : 3
        guard elements.count == expected else {
            throw CardanoCoreError.deserializeError(
                "ssc [\(kind), …]: expected \(expected) elements, got \(elements.count)")
        }
        let certificates = try decodeCertificates(elements[expected - 1])
        switch kind {
        case 0:
            let commitments = try elements[1].tagged(258, "ssccomms").array("ssccomms")
                .map(ByronSscCommitment.decode)
            return .commitments(commitments, certificates: certificates)
        case 1:
            var openings = OrderedDictionary<Data, Data>()
            for (key, value) in try elements[1].map("sscopens") {
                openings[try key.byteString("sscopens stakeholder id")] =
                    try value.byteString("sscopens vsssec")
            }
            return .openings(openings, certificates: certificates)
        case 2:
            var shares = OrderedDictionary<Data, OrderedDictionary<Data, [Data]>>()
            for (key, value) in try elements[1].map("sscshares") {
                var received = OrderedDictionary<Data, [Data]>()
                for (innerKey, innerValue) in try value.map("sscshares entry") {
                    received[try innerKey.byteString("sscshares address id")] =
                        try innerValue.array("sscshares vssdec").map {
                            try $0.byteString("sscshares vssdec")
                        }
                }
                shares[try key.byteString("sscshares address id")] = received
            }
            return .shares(shares, certificates: certificates)
        case 3:
            return .certificates(certificates)
        default:
            throw CardanoCoreError.deserializeError("ssc: unknown kind \(kind)")
        }
    }

    /// `ssccerts = #6.258([* ssccert])`
    private static func decodeCertificates(_ item: ByronCBORItem) throws -> [ByronSscCertificate] {
        try item.tagged(258, "ssccerts").array("ssccerts").map(ByronSscCertificate.decode)
    }

    private static func writeCertificates(
        _ certificates: [ByronSscCertificate], to writer: inout ByronCBORWriter
    ) {
        writer.tag(258)
        writer.definiteArray(certificates) { $1.write(to: &$0) }
    }
}

/// A VSS commitment of the SSC payload.
///
/// ```
/// ssccomm  = [pubkey, [{* vsspubkey => vssenc}, vssproof], signature]
/// vssenc   = [bytes]
/// vssproof = [bytes, bytes, bytes, [* bytes]]
/// ```
public struct ByronSscCommitment: Sendable, Equatable, Hashable {
    /// The committing stakeholder's key.
    public let publicKey: Data
    /// Encrypted shares, by the VSS key of the participant each is for.
    public let shares: OrderedDictionary<Data, [Data]>
    /// The VSS proof, in its four parts.
    public let proof: ByronVssProof
    /// The stakeholder's signature over the commitment.
    public let signature: Data

    var _original = ByronOriginalBytes()

    /// The exact bytes this commitment was decoded from.
    public var originalCBOR: Data? { _original.data }

    public init(
        publicKey: Data, shares: OrderedDictionary<Data, [Data]>, proof: ByronVssProof,
        signature: Data
    ) {
        self.publicKey = publicKey
        self.shares = shares
        self.proof = proof
        self.signature = signature
    }

    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.array(3)
        writer.bytes(publicKey)
        writer.array(2)
        writer.map(shares.count)
        for (key, encrypted) in shares {
            writer.bytes(key)
            writer.indefiniteArray(encrypted) { $0.bytes($1) }
        }
        proof.write(to: &writer)
        writer.bytes(signature)
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronSscCommitment {
        let elements = try item.array("ssccomm", count: 3)
        let content = try elements[1].array("ssccomm content", count: 2)
        var shares = OrderedDictionary<Data, [Data]>()
        for (key, value) in try content[0].map("ssccomm shares") {
            shares[try key.byteString("ssccomm vsspubkey")] =
                try value.array("vssenc").map { try $0.byteString("vssenc") }
        }
        var commitment = ByronSscCommitment(
            publicKey: try elements[0].byteString("ssccomm pubkey"),
            shares: shares,
            proof: try ByronVssProof.decode(content[1]),
            signature: try elements[2].byteString("ssccomm signature")
        )
        commitment._original = ByronOriginalBytes(item.bytes)
        return commitment
    }
}

/// A VSS proof: `vssproof = [bytes, bytes, bytes, [* bytes]]`.
///
/// The parts are the node's binary encodings of the SCRAPE proof — the
/// extra generator, the commitment proof, the parallel proofs and the
/// commitments — kept as opaque bytes.
public struct ByronVssProof: Sendable, Equatable, Hashable {
    public let extraGenerator: Data
    public let proof: Data
    public let parallelProofs: Data
    public let commitments: [Data]

    public init(extraGenerator: Data, proof: Data, parallelProofs: Data, commitments: [Data]) {
        self.extraGenerator = extraGenerator
        self.proof = proof
        self.parallelProofs = parallelProofs
        self.commitments = commitments
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronVssProof {
        let elements = try item.array("vssproof", count: 4)
        return ByronVssProof(
            extraGenerator: try elements[0].byteString("vssproof"),
            proof: try elements[1].byteString("vssproof"),
            parallelProofs: try elements[2].byteString("vssproof"),
            commitments: try elements[3].array("vssproof commitments").map {
                try $0.byteString("vssproof commitment")
            }
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(4)
        writer.bytes(extraGenerator)
        writer.bytes(proof)
        writer.bytes(parallelProofs)
        writer.indefiniteArray(commitments) { $0.bytes($1) }
    }
}

/// A VSS certificate of the SSC payload.
///
/// The CDDL gives `ssccert = [vsspubkey, pubkey, epochid, signature]`, but
/// mainnet blocks — and the node's encoder — write
/// `[vsspubkey, epochid, signature, pubkey]`, which is what this decodes.
public struct ByronSscCertificate: Sendable, Equatable, Hashable {
    /// The VSS public key being certified.
    public let vssKey: Data
    /// The last epoch the certificate is valid for.
    public let expiryEpoch: UInt64
    /// The stakeholder's signature over the VSS key and expiry epoch.
    public let signature: Data
    /// The stakeholder's signing key.
    public let signingKey: Data

    public init(vssKey: Data, expiryEpoch: UInt64, signature: Data, signingKey: Data) {
        self.vssKey = vssKey
        self.expiryEpoch = expiryEpoch
        self.signature = signature
        self.signingKey = signingKey
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronSscCertificate {
        let elements = try item.array("ssccert", count: 4)
        return ByronSscCertificate(
            vssKey: try elements[0].byteString("ssccert vsspubkey"),
            expiryEpoch: try elements[1].uint("ssccert epoch"),
            signature: try elements[2].byteString("ssccert signature"),
            signingKey: try elements[3].byteString("ssccert pubkey")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(4)
        writer.bytes(vssKey)
        writer.uint(expiryEpoch)
        writer.bytes(signature)
        writer.bytes(signingKey)
    }
}

// MARK: - Update payload

/// The update payload of a block body.
///
/// ```
/// up = [proposal : [? upprop], votes : [* upvote]]
/// ```
public struct ByronUpdatePayload: Sendable, Equatable, Hashable {
    /// The update proposal, if the block carries one.
    public var proposal: ByronUpdateProposal? { didSet { _original.data = nil } }
    /// Votes on update proposals.
    public var votes: [ByronUpdateVote] { didSet { _original.data = nil } }

    var _original = ByronOriginalBytes()

    /// The exact bytes this payload was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? {
        get { _original.data }
        set { _original.data = newValue }
    }

    public init(proposal: ByronUpdateProposal? = nil, votes: [ByronUpdateVote] = []) {
        self.proposal = proposal
        self.votes = votes
    }

    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.array(2)
        if let proposal {
            writer.array(1)
            writer.raw(try proposal.toCBORData())
        } else {
            writer.array(0)
        }
        writer.indefiniteArray(votes) { $1.write(to: &$0) }
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronUpdatePayload {
        let elements = try item.array("up", count: 2)
        let proposals = try elements[0].array("up proposal")
        guard proposals.count <= 1 else {
            throw CardanoCoreError.deserializeError("up proposal: expected at most one")
        }
        var payload = ByronUpdatePayload(
            proposal: try proposals.first.map(ByronUpdateProposal.decode),
            votes: try elements[1].array("up votes").map(ByronUpdateVote.decode)
        )
        payload.originalCBOR = item.bytes
        return payload
    }
}

/// A software and protocol update proposal.
///
/// ```
/// upprop = [ blockVersion    : bver
///          , blockVersionMod : bvermod
///          , softwareVersion : [text, u32]
///          , data            : {* text => updata}
///          , attributes      : attributes
///          , from            : pubkey
///          , signature       : signature
///          ]
/// ```
public struct ByronUpdateProposal: Sendable, Equatable, Hashable {
    /// The protocol version proposed.
    public let blockVersion: ByronBlockHeader.BlockVersion
    /// The protocol parameters the proposal changes.
    public let blockVersionModification: ByronBlockVersionModification
    /// The software version proposed.
    public let softwareVersion: ByronBlockHeader.SoftwareVersion
    /// Update data, by system tag such as `"macos64"` or `"win64"`.
    public let data: OrderedDictionary<String, ByronUpdateData>
    public let attributes: ByronAttributes
    /// The proposer's key.
    public let from: Data
    public let signature: Data

    var _original = ByronOriginalBytes()

    /// The exact bytes this proposal was decoded from.
    public var originalCBOR: Data? { _original.data }

    public init(
        blockVersion: ByronBlockHeader.BlockVersion,
        blockVersionModification: ByronBlockVersionModification,
        softwareVersion: ByronBlockHeader.SoftwareVersion,
        data: OrderedDictionary<String, ByronUpdateData>,
        attributes: ByronAttributes = .empty,
        from: Data,
        signature: Data
    ) {
        self.blockVersion = blockVersion
        self.blockVersionModification = blockVersionModification
        self.softwareVersion = softwareVersion
        self.data = data
        self.attributes = attributes
        self.from = from
        self.signature = signature
    }

    /// The proposal id that votes refer to: Blake2b-256 of the proposal's bytes.
    public var id: Data {
        ByronHash.blake2b256(try! toCBORData())
    }

    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.array(7)
        blockVersion.write(to: &writer)
        blockVersionModification.write(to: &writer)
        softwareVersion.write(to: &writer)
        writer.map(data.count)
        for (system, update) in data {
            writer.text(system)
            update.write(to: &writer)
        }
        writer.raw(try attributes.toCBORData())
        writer.bytes(from)
        writer.bytes(signature)
        return writer.data
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronUpdateProposal {
        let elements = try item.array("upprop", count: 7)
        var data = OrderedDictionary<String, ByronUpdateData>()
        for (key, value) in try elements[3].map("upprop data") {
            data[try key.text("upprop data system tag")] = try ByronUpdateData.decode(value)
        }
        var proposal = ByronUpdateProposal(
            blockVersion: try ByronBlockHeader.BlockVersion.decode(elements[0]),
            blockVersionModification: try ByronBlockVersionModification.decode(elements[1]),
            softwareVersion: try ByronBlockHeader.SoftwareVersion.decode(elements[2]),
            data: data,
            attributes: try ByronAttributes.decode(elements[4], "upprop attributes"),
            from: try elements[5].byteString("upprop from"),
            signature: try elements[6].byteString("upprop signature")
        )
        proposal._original = ByronOriginalBytes(item.bytes)
        return proposal
    }
}

/// The protocol parameter changes of an update proposal. Each field is
/// written as an array of zero or one element; `nil` leaves the parameter
/// unchanged.
///
/// ```
/// bvermod = [ scriptVersion : [? u16], slotDuration : [? bigint], maxBlockSize : [? bigint]
///           , maxHeaderSize : [? bigint], maxTxSize : [? bigint], maxProposalSize : [? bigint]
///           , mpcThd : [? u64], heavyDelThd : [? u64], updateVoteThd : [? u64]
///           , updateProposalThd : [? u64], updateImplicit : [? u64]
///           , softForkRule : [? [u64, u64, u64]], txFeePolicy : [? txfeepol]
///           , unlockStakeEpoch : [? epochid]
///           ]
/// ```
///
/// The `bigint` fields are read as unsigned integers up to `UInt64.max`.
public struct ByronBlockVersionModification: Sendable, Equatable, Hashable {
    public let scriptVersion: UInt16?
    /// Slot duration, in milliseconds.
    public let slotDuration: UInt64?
    public let maxBlockSize: UInt64?
    public let maxHeaderSize: UInt64?
    public let maxTxSize: UInt64?
    public let maxProposalSize: UInt64?
    /// Thresholds, as lovelace portions (parts of 10^15).
    public let mpcThreshold: UInt64?
    public let heavyDelegationThreshold: UInt64?
    public let updateVoteThreshold: UInt64?
    public let updateProposalThreshold: UInt64?
    /// Slots after which a proposal is adopted implicitly.
    public let updateImplicit: UInt64?
    public let softForkRule: ByronSoftForkRule?
    public let txFeePolicy: ByronTxFeePolicy?
    public let unlockStakeEpoch: UInt64?

    public init(
        scriptVersion: UInt16? = nil,
        slotDuration: UInt64? = nil,
        maxBlockSize: UInt64? = nil,
        maxHeaderSize: UInt64? = nil,
        maxTxSize: UInt64? = nil,
        maxProposalSize: UInt64? = nil,
        mpcThreshold: UInt64? = nil,
        heavyDelegationThreshold: UInt64? = nil,
        updateVoteThreshold: UInt64? = nil,
        updateProposalThreshold: UInt64? = nil,
        updateImplicit: UInt64? = nil,
        softForkRule: ByronSoftForkRule? = nil,
        txFeePolicy: ByronTxFeePolicy? = nil,
        unlockStakeEpoch: UInt64? = nil
    ) {
        self.scriptVersion = scriptVersion
        self.slotDuration = slotDuration
        self.maxBlockSize = maxBlockSize
        self.maxHeaderSize = maxHeaderSize
        self.maxTxSize = maxTxSize
        self.maxProposalSize = maxProposalSize
        self.mpcThreshold = mpcThreshold
        self.heavyDelegationThreshold = heavyDelegationThreshold
        self.updateVoteThreshold = updateVoteThreshold
        self.updateProposalThreshold = updateProposalThreshold
        self.updateImplicit = updateImplicit
        self.softForkRule = softForkRule
        self.txFeePolicy = txFeePolicy
        self.unlockStakeEpoch = unlockStakeEpoch
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronBlockVersionModification {
        let fields = try item.array("bvermod", count: 14)
        func optional<T>(_ index: Int, _ read: (ByronCBORItem) throws -> T) throws -> T? {
            let values = try fields[index].array("bvermod field \(index)")
            guard values.count <= 1 else {
                throw CardanoCoreError.deserializeError(
                    "bvermod field \(index): expected at most one element")
            }
            return try values.first.map(read)
        }
        func uint(_ index: Int) throws -> UInt64? {
            try optional(index) { try $0.uint("bvermod field \(index)") }
        }
        return ByronBlockVersionModification(
            scriptVersion: try optional(0) { try $0.uint("bvermod scriptVersion", as: UInt16.self) },
            slotDuration: try uint(1),
            maxBlockSize: try uint(2),
            maxHeaderSize: try uint(3),
            maxTxSize: try uint(4),
            maxProposalSize: try uint(5),
            mpcThreshold: try uint(6),
            heavyDelegationThreshold: try uint(7),
            updateVoteThreshold: try uint(8),
            updateProposalThreshold: try uint(9),
            updateImplicit: try uint(10),
            softForkRule: try optional(11, ByronSoftForkRule.decode),
            txFeePolicy: try optional(12, ByronTxFeePolicy.decode),
            unlockStakeEpoch: try uint(13)
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        func optional<T>(_ value: T?, _ write: (inout ByronCBORWriter, T) -> Void) {
            if let value {
                writer.array(1)
                write(&writer, value)
            } else {
                writer.array(0)
            }
        }
        writer.array(14)
        optional(scriptVersion) { $0.uint($1) }
        for value in [
            slotDuration, maxBlockSize, maxHeaderSize, maxTxSize, maxProposalSize,
            mpcThreshold, heavyDelegationThreshold, updateVoteThreshold,
            updateProposalThreshold, updateImplicit,
        ] {
            optional(value) { $0.uint($1) }
        }
        optional(softForkRule) { $1.write(to: &$0) }
        optional(txFeePolicy) { $1.write(to: &$0) }
        optional(unlockStakeEpoch) { $0.uint($1) }
    }
}

/// The soft fork rule: `[u64, u64, u64]` — the initial threshold, the
/// minimum threshold and the threshold decrement, as lovelace portions.
public struct ByronSoftForkRule: Sendable, Equatable, Hashable {
    public let initThreshold: UInt64
    public let minThreshold: UInt64
    public let thresholdDecrement: UInt64

    public init(initThreshold: UInt64, minThreshold: UInt64, thresholdDecrement: UInt64) {
        self.initThreshold = initThreshold
        self.minThreshold = minThreshold
        self.thresholdDecrement = thresholdDecrement
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronSoftForkRule {
        let elements = try item.array("softForkRule", count: 3)
        return ByronSoftForkRule(
            initThreshold: try elements[0].uint("softForkRule"),
            minThreshold: try elements[1].uint("softForkRule"),
            thresholdDecrement: try elements[2].uint("softForkRule")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(3)
        writer.uint(initThreshold)
        writer.uint(minThreshold)
        writer.uint(thresholdDecrement)
    }
}

/// The transaction fee policy.
///
/// ```
/// txfeepol = [0, #6.24(bytes .cbor ([bigint, bigint]))] / [u8 .gt 0, encoded-cbor]
/// ```
public enum ByronTxFeePolicy: Sendable, Equatable, Hashable {
    /// `[0, #6.24([a, b])]` — a fee of `a + b × size`, both scaled by 10^9
    /// as the node writes them.
    case linear(constant: Int64, perByte: Int64)
    /// `[tag, payload]` for a tag the ledger does not define; `payload` is the
    /// CBOR of the second element as written.
    case unknown(tag: UInt8, payload: Data)

    static func decode(_ item: ByronCBORItem) throws -> ByronTxFeePolicy {
        let elements = try item.array("txfeepol", count: 2)
        let tag = try elements[0].uint("txfeepol tag", as: UInt8.self)
        guard tag == 0 else {
            return .unknown(tag: tag, payload: elements[1].bytes)
        }
        let pair = try elements[1].embedded("txfeepol").array("txfeepol [a, b]", count: 2)
        return .linear(
            constant: try pair[0].int("txfeepol a"),
            perByte: try pair[1].int("txfeepol b")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(2)
        switch self {
        case .linear(let constant, let perByte):
            writer.uint(0 as UInt8)
            writer.embedded(ByronCBORWriter.encode {
                $0.array(2)
                $0.int(constant)
                $0.int(perByte)
            })
        case .unknown(let tag, let payload):
            writer.uint(tag)
            writer.raw(payload)
        }
    }
}

/// Hashes of an update for one system: `updata = [hash, hash, hash, hash]`.
public struct ByronUpdateData: Sendable, Equatable, Hashable {
    public let appDiffHash: Data
    public let packageHash: Data
    public let updaterHash: Data
    public let metadataHash: Data

    public init(appDiffHash: Data, packageHash: Data, updaterHash: Data, metadataHash: Data) {
        self.appDiffHash = appDiffHash
        self.packageHash = packageHash
        self.updaterHash = updaterHash
        self.metadataHash = metadataHash
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronUpdateData {
        let elements = try item.array("updata", count: 4)
        return ByronUpdateData(
            appDiffHash: try elements[0].byteString("updata", count: 32),
            packageHash: try elements[1].byteString("updata", count: 32),
            updaterHash: try elements[2].byteString("updata", count: 32),
            metadataHash: try elements[3].byteString("updata", count: 32)
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(4)
        writer.bytes(appDiffHash)
        writer.bytes(packageHash)
        writer.bytes(updaterHash)
        writer.bytes(metadataHash)
    }
}

/// A vote on an update proposal.
///
/// ```
/// upvote = [voter : pubkey, proposalId : updid, vote : bool, signature : signature]
/// ```
public struct ByronUpdateVote: Sendable, Equatable, Hashable {
    public let voter: Data
    /// The id of the proposal voted on: the hash of the proposal.
    public let proposalId: Data
    /// `true` for a vote in favour.
    public let vote: Bool
    public let signature: Data

    public init(voter: Data, proposalId: Data, vote: Bool, signature: Data) {
        self.voter = voter
        self.proposalId = proposalId
        self.vote = vote
        self.signature = signature
    }

    static func decode(_ item: ByronCBORItem) throws -> ByronUpdateVote {
        let elements = try item.array("upvote", count: 4)
        return ByronUpdateVote(
            voter: try elements[0].byteString("upvote voter"),
            proposalId: try elements[1].byteString("upvote proposalId", count: 32),
            vote: try elements[2].bool("upvote vote"),
            signature: try elements[3].byteString("upvote signature")
        )
    }

    func write(to writer: inout ByronCBORWriter) {
        writer.array(4)
        writer.bytes(voter)
        writer.bytes(proposalId)
        writer.bool(vote)
        writer.bytes(signature)
    }
}
