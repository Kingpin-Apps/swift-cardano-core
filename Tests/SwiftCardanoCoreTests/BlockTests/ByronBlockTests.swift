import BigInt
import CBORCodable
import Foundation
import Testing
import OrderedCollections

@testable import SwiftCardanoCore

/// Real mainnet Byron blocks, from txpipe/pallas `test_data/` (hex text):
///
/// | file            | block                                | contents                          |
/// |-----------------|--------------------------------------|-----------------------------------|
/// | `genesis.block` | EBB of epoch 0, the first block      | 21600 stakeholder ids             |
/// | `byron1.block`  | epoch 207 slot 21594, height 4490505 | no transactions                   |
/// | `byron2.block`  | epoch 150 slot 1381                  | 2 transactions                    |
/// | `byron3.block`  | epoch 150 slot 1                     | SSC commitments and certificates  |
/// | `byron4.block`  | epoch 1 slot 21591                   | 1 transaction                     |
/// | `byron5.block`  | epoch 3 slot 8686                    | 1 transaction, update proposal    |
/// |                 |                                      | and vote, SSC openings            |
/// | `byron6.block`  | epoch 160 slot 17280                 | 1 transaction, SSC shares         |
/// | `byron1.header` | header of the block after byron1     |                                   |
/// | `byron1.tx`     | the first `[tx, [* twit]]` of byron2 |                                   |
///
/// The block hashes, transaction ids, slots and heights below were checked
/// against mainnet with Koios (`block_info`, `tx_info`); the hash of byron1
/// is also the `prevBlock` of `byron1.header`.
@Suite("Byron blocks")
struct ByronBlockTests {

    struct Vector: Sendable, CustomTestStringConvertible {
        var file: String
        var hash: String
        var transactionIds: [String]

        var testDescription: String { file }

        func bytes() throws -> Data {
            try ByronBlockTests.load(file)
        }
    }

    static let vectors: [Vector] = [
        Vector(
            file: "genesis.block",
            hash: "89d9b5a5b8ddc8d7e5a6795e9774d97faf1efea59b2caf7eaf9f8c5b32059df4",
            transactionIds: []),
        Vector(
            file: "byron1.block",
            hash: "5c196e7394ace0449ba5a51c919369699b13896e97432894b4f0354dce8670b6",
            transactionIds: []),
        Vector(
            file: "byron2.block",
            hash: "5a4f135aac8083df35161afca982d2cbd6c752421ae292ad09735b982d86ce40",
            transactionIds: [
                "a06e5a0150e09f8983be2deafab9e04afc60d92e7110999eb672c903343f1e26",
                "f736d55633782151cd528f9918c3587155cbd59c46b6ca839e5b4860a780f379",
            ]),
        Vector(
            file: "byron3.block",
            hash: "83070c12c45e8566797b7bef3e75e4fd6a33520c01f7d8bdb936ae74bc7eca7c",
            transactionIds: []),
        Vector(
            file: "byron4.block",
            hash: "de23eaf0d9d3960d11c0c44e45f17980a34c11694aaeab06acb0252639e6635d",
            transactionIds: ["7ec77545db0e4aa5cf7cab10560f0d5e00ff03d37d776f86a16b2cb85d0e8c36"]),
        Vector(
            file: "byron5.block",
            hash: "9f63162b78765332c1632f46960fb386da7a2916090e2ef155ab97941ee1bbb9",
            transactionIds: ["f5b7a771559e6ae050d2001f95d0119d8ed39b09ca9bf72db670237973a7b9a4"]),
        Vector(
            file: "byron6.block",
            hash: "12078aac48c421a492dcfe43c10041c19814cde99f304c1d01e9abb748bc4e0f",
            transactionIds: ["6dca0cbecf564503e2490c6f88ca962b9145ba4f52c4d9a45ed01f0482a71371"]),
    ]

    static func load(_ file: String) throws -> Data {
        let url = try #require(
            Bundle.module.resourceURL?.appendingPathComponent("data/byron/\(file)"))
        let hex = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try #require(Data(hexString: hex))
    }

    static func block(_ file: String) throws -> ByronBlock {
        try ByronBlock.fromCBOR(data: try load(file))
    }

    static func bft(_ file: String) throws -> ByronBlock.BFT {
        guard case .bft(let bft) = try block(file) else {
            Issue.record("\(file) is not a regular block")
            throw CardanoCoreError.deserializeError("not a regular block")
        }
        return bft
    }

    static let mainnetMagic: UInt32 = 764_824_073

    // MARK: - Round trips

    @Test("Decoding and re-encoding gives back the exact bytes", arguments: vectors)
    func roundTrip(_ vector: Vector) throws {
        let bytes = try vector.bytes()
        let block = try ByronBlock.fromCBOR(data: bytes)
        #expect(block.originalCBOR == bytes)
        #expect(try block.toCBORData() == bytes)
        #expect(try CBOREncoder().encode(block) == bytes)
        #expect(try ByronBlock(from: block.toPrimitive()) == block)
    }

    @Test("EraBlock era 0 keeps the bytes, bare and network-wrapped", arguments: vectors)
    func eraBlockRoundTrip(_ vector: Vector) throws {
        let bytes = try vector.bytes()
        let eraBlock = try EraBlock.fromBlockCBOR(data: bytes, era: 0)
        guard case .byron(let block) = eraBlock else {
            Issue.record("expected a Byron block")
            return
        }
        #expect(try block.toCBORData() == bytes)
        #expect(try block.hash().toHex == vector.hash)

        var wrapper = ByronCBORWriter()
        wrapper.array(2)
        wrapper.uint(0 as UInt8)
        wrapper.embedded(bytes)
        let network = try EraBlock.fromNetworkCBOR(data: wrapper.data)
        #expect(network == eraBlock)
        #expect(try network.toCBORData() == wrapper.data)
    }

    /// Rebuilding every part from its decoded fields, so nothing has bytes to
    /// keep, still gives the mainnet bytes — which checks the encoder for
    /// each part, not only the kept bytes.
    @Test("Every part re-encoded from its fields gives the mainnet bytes", arguments: vectors)
    func freshEncoding(_ vector: Vector) throws {
        let bytes = try vector.bytes()
        let rebuilt: ByronBlock
        switch try ByronBlock.fromCBOR(data: bytes) {
        case .ebb(let ebb):
            rebuilt = .ebb(
                ByronBlock.EBB(
                    header: Self.rebuilt(ebb.header), body: ebb.body,
                    extra: ebb.extra.map(Self.rebuilt)))
        case .bft(let bft):
            rebuilt = .bft(
                ByronBlock.BFT(
                    header: Self.rebuilt(bft.header), body: Self.rebuilt(try #require(bft.body)),
                    extra: bft.extra.map(Self.rebuilt)))
        }
        #expect(rebuilt.originalCBOR == nil)
        #expect(try rebuilt.toCBORData() == bytes)
        #expect(try rebuilt.hash().toHex == vector.hash)
    }

    // MARK: - Hashes

    @Test("Block hashes and transaction ids match mainnet", arguments: vectors)
    func hashesMatchMainnet(_ vector: Vector) throws {
        let block = try ByronBlock.fromCBOR(data: try vector.bytes())
        #expect(try block.hash().toHex == vector.hash)
        #expect(try block.header.hash().toHex == vector.hash)
        guard case .bft(let bft) = block else {
            #expect(vector.transactionIds.isEmpty)
            return
        }
        #expect(try bft.transactions.map { try $0.id.payload.toHex } == vector.transactionIds)
        #expect(try bft.transactions.map { try $0.transaction.hash().toHex } == vector.transactionIds)
    }

    @Test("The next block's header points back at byron1")
    func nextHeaderLinksBack() throws {
        let headerBytes = try Self.load("byron1.header")
        let header = try ByronBlockHeader.fromCBOR(data: headerBytes)
        guard case .bft(let head) = header else {
            Issue.record("expected a regular header")
            return
        }
        #expect(try header.toCBORData() == headerBytes)
        #expect(try head.prevBlock == (try Self.block("byron1.block")).hash())
        #expect(head.slotId == ByronBlockHeader.SlotId(epoch: 207, slot: 21595))
        #expect(head.difficulty == 4_490_506)
        // Mainnet block 4490506.
        #expect(try header.hash().toHex == "2548ad5d0d9d33d50ab43151f574474454017a733e307229fa509c4987ca9782")
    }

    @Test("Body proofs commit to the payload bytes", arguments: vectors)
    func bodyProofsMatchPayloads(_ vector: Vector) throws {
        switch try ByronBlock.fromCBOR(data: try vector.bytes()) {
        case .ebb(let ebb):
            let body = ByronCBORWriter.encode { writer in
                writer.indefiniteArray(ebb.body ?? []) { $0.bytes($1) }
            }
            #expect(try ByronHash.blake2b256(body) == ebb.header.bodyProof)
        case .bft(let bft):
            let body = try #require(bft.body)
            let delegation = ByronCBORWriter.encode { writer in
                writer.indefiniteArray(body.delegationPayload) { $1.write(to: &$0) }
            }
            let extra = try ByronCBORWriter.encode { writer in
                writer.array(bft.extra.count)
                for attributes in bft.extra { writer.raw(try attributes.toCBORData()) }
            }
            #expect(try ByronHash.blake2b256(delegation) == bft.header.bodyProof.dlgProof)
            #expect(try ByronHash.blake2b256(try body.updatePayload.toCBORData()) == bft.header.bodyProof.updProof)
            #expect(try ByronHash.blake2b256(extra) == bft.header.extraProof)
            #expect(Int(bft.header.bodyProof.txProof.transactionCount) == bft.transactionCount)
        }
    }

    // MARK: - Decoded fields

    @Test("The genesis EBB decodes in full")
    func genesisEBB() throws {
        guard case .ebb(let ebb) = try Self.block("genesis.block") else {
            Issue.record("expected an EBB")
            return
        }
        #expect(ebb.protocolMagic == Self.mainnetMagic)
        // The mainnet genesis hash.
        #expect(ebb.header.prevBlock.toHex == "5f20df933584822601f9e3f8c024eb5eb252fe8cefb24d1317dc3d432e940ebb")
        #expect(ebb.header.bodyProof.toHex == "54f0972807b68698fcd704e3dae675dc43c8a6656aeaf4891e6e3f23be2de00a")
        #expect(ebb.epoch == 0)
        #expect(ebb.difficulty == 0)
        #expect(ebb.header.attributes.isEmpty)
        let body = try #require(ebb.body)
        #expect(body.count == 21600)
        #expect(body.first?.toHex == "af2800c124e599d6dec188a75f8bfde397ebb778163a18240371f2d1")
        #expect(body.allSatisfy { $0.count == 28 })
        #expect(ebb.extra == [.empty])
        #expect(ebb.blockSizeHint == nil)
    }

    @Test("A block's header fields decode")
    func headerFields() throws {
        let bft = try Self.bft("byron1.block")
        let header = bft.header
        #expect(bft.protocolMagic == Self.mainnetMagic)
        #expect(bft.prevHash?.toHex == "a5a5c235200bbe91f16cd3e5dcb67369c25dcfb1279c83d22021f5d960c485e6")
        #expect(bft.epoch == 207)
        #expect(bft.slotWithinEpoch == 21594)
        #expect(bft.absoluteSlot() == 4_492_794)
        #expect(bft.difficulty == 4_490_505)
        #expect(bft.protocolVersion == ByronBlockHeader.BlockVersion(major: 2, minor: 0, alt: 0))
        #expect(bft.softwareVersion == ByronBlockHeader.SoftwareVersion(appName: "cardano-sl", number: 1))
        #expect(bft.transactionCount == 0)
        #expect(bft.issuerVKey.toHex.hasPrefix("26566e86fc6b9b17"))
        #expect(bft.issuerVKey.count == 64)

        let proof = header.bodyProof
        #expect(proof.txProof.transactionCount == 0)
        #expect(proof.txProof.merkleRoot.toHex == "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8")
        #expect(proof.sscProof == .certificates(
            certificatesHash: try #require(Data(hexString: "d36a2619a672494604e11bb447cbcf5231e9f2ba25c2169177edc941bd50ad6c"))))
        #expect(header.extraProof.toHex == "4ba92aa320c60acc9ad7b9a64f2eda55c4d2ec28e604faf186708b4f0c4e8edf")
        #expect(header.attributes.isEmpty)

        guard case .delegation(let signature) = header.signature else {
            Issue.record("expected a heavy delegation signature")
            return
        }
        #expect(signature.delegation.epoch == 0)
        #expect(signature.delegation.issuer == header.issuerKey)
        #expect(signature.delegation.delegate.toHex.hasPrefix("f14f712dc600d793"))
        #expect(signature.signature.count == 64)

        let body = try #require(bft.body)
        #expect(body.sscPayload == .certificates([]))
        #expect(body.delegationPayload.isEmpty)
        #expect(body.updatePayload == ByronUpdatePayload())
    }

    @Test("Transactions decode in full")
    func transactionFields() throws {
        let bft = try Self.bft("byron2.block")
        #expect(bft.epoch == 150)
        #expect(bft.slotWithinEpoch == 1381)
        #expect(bft.absoluteSlot() == 3_241_381)
        #expect(bft.transactionCount == 2)

        let first = bft.transactions[0]
        #expect(first.transaction.inputs == [
            .utxo(
                transactionId: TransactionId(payload: try #require(Data(
                    hexString: "da832fb5ef57df5b91817e9a7448d26e92552afb34f8ee5adb491b24bbe990d5"))),
                index: 14),
        ])
        #expect(first.transaction.outputs.map(\.amount) == [6_218_600_000, 13_780_227_567])
        #expect(first.transaction.outputs.map { $0.address.toBase58() } == [
            "DdzFFzCqrht8QHTQXbWy2qoyPaqTN8BjyfKygGmpy9dtot1tvkBfCaVTnR22XCaaDVn3M1U6aiMShoCLzw6VWSwzQKhhJrM3YjYp3wyy",
            "DdzFFzCqrhsjUjMRukzoFx8sToHzCt4iidB17STXk9adAoVMNus5SvAjS1cXfPKbuNbPUZ5xQG25sMK85n9GdMkqo2ytqBnKWC68s8P3",
        ])
        #expect(first.transaction.attributes.isEmpty)
        #expect(first.witnesses.count == 1)
        guard case .publicKey(let publicKey, let signature) = first.witnesses[0] else {
            Issue.record("expected a public key witness")
            return
        }
        #expect(publicKey.count == 64)
        #expect(signature.count == 64)

        let second = bft.transactions[1]
        #expect(second.transaction.inputs.count == 6)
        #expect(second.transaction.outputs.count == 6)
        #expect(second.witnesses.count == 6)
        #expect(second.transaction.outputs[0].amount == 75_550_373_000)
        #expect(second.transaction.outputs[0].address.toBase58()
            == "Ae2tdPwUPEZFBnsqpm2RkDQfwJseUrBKrTECCDom4bAqNsxTNwbMPCZtbyJ")
        #expect(second.transaction.outputs.map(\.amount).reduce(0, +) == 804_445_220_858)
    }

    @Test("A standalone transaction with witnesses decodes and keeps its id")
    func transactionAux() throws {
        let bytes = try Self.load("byron1.tx")
        let aux = try ByronTransactionAux.fromCBOR(data: bytes)
        #expect(try aux.toCBORData() == bytes)
        #expect(try aux.id.payload.toHex == "a06e5a0150e09f8983be2deafab9e04afc60d92e7110999eb672c903343f1e26")
        #expect(aux == (try Self.bft("byron2.block")).transactions[0])

        let transaction = try ByronTransaction.fromCBOR(data: try aux.transaction.toCBORData())
        #expect(try transaction.id == aux.id)
    }

    @Test("SSC commitments and certificates decode")
    func sscCommitments() throws {
        let body = try #require((try Self.bft("byron3.block")).body)
        guard case .commitments(let commitments, let certificates) = body.sscPayload else {
            Issue.record("expected commitments")
            return
        }
        #expect(commitments.count == 1)
        let commitment = commitments[0]
        #expect(commitment.publicKey.toHex.hasPrefix("89c29f8c4af27b7a"))
        #expect(commitment.shares.count == 7)
        #expect(commitment.shares.values.allSatisfy { $0.count == 1 })
        #expect(commitment.proof.commitments.count == 7)
        #expect(commitment.signature.count == 64)

        #expect(certificates.count == 7)
        #expect(certificates.allSatisfy { $0.expiryEpoch == 155 })
        // The committing stakeholder certifies its own VSS key: the
        // certificate's last field is the signing key.
        #expect(certificates.contains { $0.signingKey == commitment.publicKey })
        #expect(Set(certificates.map(\.vssKey)) == Set(commitment.shares.keys))
    }

    @Test("SSC openings and shares decode")
    func sscOpeningsAndShares() throws {
        let openings = try #require((try Self.bft("byron5.block")).body).sscPayload
        #expect(openings == .openings([:], certificates: []))

        let body = try #require((try Self.bft("byron6.block")).body)
        guard case .shares(let shares, let certificates) = body.sscPayload else {
            Issue.record("expected shares")
            return
        }
        #expect(certificates.isEmpty)
        let id = try #require(Data(hexString: "0efd6f3b2849d5baf25b3e2bf2d46f88427b4e455fc3dc43f57819c5"))
        #expect(Array(shares.keys) == [id])
        #expect(shares[id]?.count == 1)
        #expect(shares[id]?[id]?.count == 1)
        #expect(shares[id]?[id]?.first?.count == 99)
    }

    @Test("An update proposal decodes in full")
    func updateProposal() throws {
        let bft = try Self.bft("byron5.block")
        #expect(bft.epoch == 3)
        #expect(bft.slotWithinEpoch == 8686)
        let update = try #require(bft.body).updatePayload
        let proposal = try #require(update.proposal)
        #expect(try proposal.id.toHex == "0d7d3b53a0ef9ce40fa9222cfc2b725f52c0136c01ad366115b48f94d8ef2c6d")
        // The proposer votes for its own proposal in the same block.
        let proposalId = try proposal.id
        #expect(update.votes == [
            ByronUpdateVote(
                voter: proposal.from, proposalId: proposalId, vote: true,
                signature: try #require(Data(hexString:
                    "d723f2794e5206c38b9ed6433190cd75e89ab1e3d9324c89fe0925b924c81b2fadbf83f3e232f583efcb1eae345e3149073e2d85c0eb85324874f13118ce340d"))),
        ])
        #expect(proposal.blockVersion == .zero)
        #expect(proposal.softwareVersion == ByronBlockHeader.SoftwareVersion(appName: "csl-daedalus", number: 1))
        #expect(Array(proposal.data.keys) == ["macos64", "win64"])
        #expect(proposal.data["win64"]?.packageHash.toHex
            == "828339268d84c542d3543a878ccba21887fbf01fb154d333b945217dedba9c3a")
        #expect(proposal.attributes.isEmpty)
        #expect(proposal.from.count == 64)
        #expect(proposal.signature.count == 64)
        #expect(proposal.blockVersionModification == ByronBlockVersionModification(
            scriptVersion: 0,
            slotDuration: 20000,
            maxBlockSize: 2_000_000,
            maxHeaderSize: 2_000_000,
            maxTxSize: 4096,
            maxProposalSize: 700,
            mpcThreshold: 20_000_000_000_000,
            heavyDelegationThreshold: 300_000_000_000,
            updateVoteThreshold: 1_000_000_000_000,
            updateProposalThreshold: 100_000_000_000_000,
            updateImplicit: 10000
        ))
    }

    // MARK: - Changes

    @Test("Changing a transaction re-encodes it alone")
    func changingATransaction() throws {
        let bytes = try Self.load("byron2.block")
        var bft = try Self.bft("byron2.block")
        let untouched = try bft.transactions[1].toCBORData()
        let headerBytes = try bft.header.toCBORData()

        var body = try #require(bft.body)
        body.transactions[0].transaction.outputs[0].amount += 1
        bft.body = body
        #expect(bft.originalCBOR == nil)
        #expect(bft.body?.originalCBOR == nil)
        #expect(bft.transactions[0].originalCBOR == nil)
        #expect(bft.transactions[0].transaction.originalCBOR == nil)
        #expect(bft.transactions[1].originalCBOR == untouched)

        let changed = try ByronBlock.bft(bft).toCBORData()
        #expect(changed != bytes)
        #expect(changed.count == bytes.count)
        #expect(changed.range(of: untouched) != nil)
        #expect(changed.range(of: headerBytes) != nil)

        // The header is untouched, so the block hash is too; the changed
        // transaction has a new id, and decoding the new bytes gives it back.
        let decoded = try ByronBlock.fromCBOR(data: changed)
        #expect(try decoded.hash() == ByronBlock.bft(bft).hash())
        guard case .bft(let decodedBFT) = decoded else {
            Issue.record("expected a regular block")
            return
        }
        #expect(decodedBFT == bft)
        #expect(try decodedBFT.transactions[0].id != (try Self.bft("byron2.block")).transactions[0].id)
        #expect(try decodedBFT.transactions[1].id.payload.toHex
            == "f736d55633782151cd528f9918c3587155cbd59c46b6ca839e5b4860a780f379")
    }

    @Test("Changing the header changes the block hash")
    func changingTheHeader() throws {
        var bft = try Self.bft("byron1.block")
        let bodyBytes = try #require(bft.body).toCBORData()
        bft.header.difficulty += 1
        #expect(bft.header.originalCBOR == nil)
        let changed = try ByronBlock.bft(bft).toCBORData()
        #expect(changed.range(of: bodyBytes) != nil)
        let decoded = try ByronBlock.fromCBOR(data: changed)
        #expect(decoded.difficulty == 4_490_506)
        #expect(try decoded.hash().toHex != Self.vectors[1].hash)
    }

    /// No vector carries a delegation certificate in its body, so this checks
    /// one written into a mainnet block survives a round trip.
    @Test("A delegation payload round-trips")
    func delegationPayload() throws {
        var bft = try Self.bft("byron1.block")
        guard case .delegation(let signature) = bft.header.signature else {
            Issue.record("expected a heavy delegation signature")
            return
        }
        var body = try #require(bft.body)
        body.delegationPayload = [signature.delegation]
        bft.body = body
        let encoded = try ByronBlock.bft(bft).toCBORData()
        let decoded = try ByronBlock.fromCBOR(data: encoded)
        guard case .bft(let decodedBFT) = decoded else {
            Issue.record("expected a regular block")
            return
        }
        #expect(decodedBFT.body?.delegationPayload == [signature.delegation])
        #expect(try decoded.toCBORData() == encoded)
    }

    // MARK: - Network forms

    @Test("The NtN header-only form decodes and keeps its bytes")
    func headerOnlyForm() throws {
        let blockBytes = try Self.load("byron1.block")
        let bft = try Self.bft("byron1.block")
        let headerBytes = try bft.header.toCBORData()
        var writer = ByronCBORWriter()
        writer.array(2)
        writer.array(2)
        writer.uint(1 as UInt8)
        writer.uint(UInt32(blockBytes.count))
        writer.embedded(headerBytes)
        let ntn = writer.data

        guard case .byron(let block) = try EraBlock.fromBlockCBOR(data: ntn, era: 0),
            case .bft(let headerOnly) = block
        else {
            Issue.record("expected a Byron regular block")
            return
        }
        #expect(block.isHeaderOnly)
        #expect(headerOnly.blockSizeHint == UInt32(blockBytes.count))
        #expect(headerOnly.header == bft.header)
        #expect(headerOnly.transactionCount == 0)
        #expect(try block.hash() == bft.hash())
        #expect(try block.toCBORData() == ntn)

        var changed = headerOnly
        changed.blockSizeHint = 1
        #expect(changed.originalCBOR == nil)
        #expect(try ByronBlock.bft(changed).toCBORData() != ntn)
        #expect(try ByronBlock.fromCBOR(data: ByronBlock.bft(changed).toCBORData()) == .bft(changed))

        let eraHeader = try EraBlockHeader.fromByronNtNData(ntn)
        #expect(eraHeader.byronHeader == .bft(bft.header))
        #expect(try eraHeader.byronHeader?.hash() == bft.hash())
    }

    @Test("EraBlockHeader era 0 keeps the header bytes")
    func eraBlockHeader() throws {
        let headerBytes = try Self.load("byron1.header")
        var writer = ByronCBORWriter()
        writer.array(2)
        writer.uint(0 as UInt8)
        writer.embedded(headerBytes)
        let eraHeader = try EraBlockHeader.fromCBOR(data: writer.data)
        #expect(eraHeader.byronHeader?.originalCBOR == headerBytes)
        #expect(try eraHeader.toCBORData() == writer.data)
    }

    // MARK: - JSON

    @Test("JSON round-trips through the block's bytes", arguments: [vectors[0], vectors[2]])
    func json(_ vector: Vector) throws {
        let block = try ByronBlock.fromCBOR(data: try vector.bytes())
        let dict = try block.toDict()
        guard case .orderedDict(let fields) = dict else {
            Issue.record("expected a dict")
            return
        }
        #expect(fields[.string("hash")] == .string(vector.hash))
        let restored = try ByronBlock.fromDict(dict)
        #expect(restored == block)
        #expect(try restored.toCBORData() == vector.bytes())

        let eraBlock = EraBlock.byron(block)
        #expect(try EraBlock.fromDict(eraBlock.toDict()) == eraBlock)
    }

    // MARK: - Helpers

    /// Copies of decoded parts with no bytes to keep, built from their fields.
    static func rebuilt(_ attributes: ByronAttributes) -> ByronAttributes {
        ByronAttributes(attributes.entries)
    }

    static func rebuilt(_ head: ByronBlockHeader.EBBHead) -> ByronBlockHeader.EBBHead {
        ByronBlockHeader.EBBHead(
            protocolMagic: head.protocolMagic, prevBlock: head.prevBlock,
            bodyProof: head.bodyProof, epoch: head.epoch, difficulty: head.difficulty,
            attributes: rebuilt(head.attributes))
    }

    static func rebuilt(_ head: ByronBlockHeader.BFTHead) -> ByronBlockHeader.BFTHead {
        ByronBlockHeader.BFTHead(
            protocolMagic: head.protocolMagic, prevBlock: head.prevBlock,
            bodyProof: head.bodyProof, slotId: head.slotId, issuerKey: head.issuerKey,
            difficulty: head.difficulty, signature: head.signature,
            blockVersion: head.blockVersion, softwareVersion: head.softwareVersion,
            attributes: rebuilt(head.attributes), extraProof: head.extraProof)
    }

    static func rebuilt(_ body: ByronBlockBody) -> ByronBlockBody {
        let ssc: ByronSscPayload
        switch body.sscPayload {
        case .commitments(let commitments, let certificates):
            ssc = .commitments(
                commitments.map {
                    ByronSscCommitment(
                        publicKey: $0.publicKey, shares: $0.shares, proof: $0.proof,
                        signature: $0.signature)
                }, certificates: certificates)
        default:
            ssc = body.sscPayload
        }
        let proposal = body.updatePayload.proposal.map {
            ByronUpdateProposal(
                blockVersion: $0.blockVersion,
                blockVersionModification: $0.blockVersionModification,
                softwareVersion: $0.softwareVersion, data: $0.data,
                attributes: rebuilt($0.attributes), from: $0.from, signature: $0.signature)
        }
        return ByronBlockBody(
            transactions: body.transactions.map {
                ByronTransactionAux(
                    transaction: ByronTransaction(
                        inputs: $0.transaction.inputs, outputs: $0.transaction.outputs,
                        attributes: rebuilt($0.transaction.attributes)),
                    witnesses: $0.witnesses)
            },
            sscPayload: ssc,
            delegationPayload: body.delegationPayload,
            updatePayload: ByronUpdatePayload(proposal: proposal, votes: body.updatePayload.votes)
        )
    }
}

@Suite("Byron parameter updates read bigints as the ledger does")
struct ByronBigintTests {
    @Test("A bigint field holds a bignum beyond 64 bits, and a small one written as a bignum")
    func bignumFields() throws {
        // bvermod with maxBlockSize = 2^64 and every other field left unchanged.
        let hex = "8e" + "8080" + "81c249010000000000000000" + String(repeating: "80", count: 11)
        let item = try ByronCBORItem(root: hex.hexStringToData, "bvermod")
        let modification = try ByronBlockVersionModification.decode(item)
        #expect(modification.maxBlockSize == BigUInt(1) << 64)
        #expect(ByronCBORWriter.encode { modification.write(to: &$0) }.toHex == hex)

        let small = try ByronCBORItem(root: "c24101".hexStringToData, "bigint")
        #expect(try small.natural("bigint") == 1)
        #expect(throws: CardanoCoreError.self) {
            try ByronCBORItem(root: "20".hexStringToData, "bigint").natural("bigint")
        }
    }
}
