import BigInt
import Foundation
import OrderedCollections
import Testing

@testable import SwiftCardanoCore

/// Certificates as the chain writes them: each must decode, re-encode to the
/// bytes it was read from, and survive a trip through its dict form.
@Suite("Certificate decoding")
struct CertificateDecodingTests {
    // MARK: - Helpers

    static func zeros(_ count: Int) -> String { String(repeating: "00", count: count) }
    static func repeated(_ byte: String, _ count: Int) -> String { String(repeating: byte, count: count) }

    /// The bytes of every certificate in a transaction body, as written.
    static func certificateBytes(inBody body: Data) throws -> [Data] {
        let scanner = CBORItemScanner(body)
        for (key, value) in try scanner.entries(ofMapAt: 0)
        where try scanner.unsignedInteger(at: key.lowerBound) == 4 {
            // Conway may tag the certificates as a set (258).
            let start = try scanner.untagged(at: value.lowerBound)
            return try scanner.elements(ofArrayAt: start).map { scanner.bytes.subdata(in: $0) }
        }
        return []
    }

    /// The written bytes of a transaction's body.
    static func bodyBytes(ofTransaction bytes: Data) throws -> Data {
        let scanner = CBORItemScanner(bytes)
        let spans = try scanner.elements(ofArrayAt: 0)
        return scanner.bytes.subdata(in: spans[0])
    }

    /// Checks that each decoded certificate re-encodes to its written bytes,
    /// on its own and through its text-envelope payload and dict form.
    static func expectCertificatesRoundTrip(_ certificates: [Certificate], written: [Data]) throws {
        #expect(certificates.count == written.count)
        for (certificate, bytes) in zip(certificates, written) {
            #expect(try certificate.toCBORData() == bytes)
            // Decoding the certificate alone gives the same bytes.
            let alone = try Certificate.fromCBOR(data: bytes)
            #expect(try alone.toCBORData() == bytes)
            // The dict form keeps everything the bytes hold.
            let fromDict = try Certificate.fromDict(try certificate.toDict())
            #expect(try fromDict.toCBORData() == bytes)
        }
    }

    // MARK: - Real mainnet transactions with MIR certificates

    /// Mainnet transactions carrying `move_instantaneous_rewards_cert`s.
    ///
    /// The ids were found with Koios (`https://api.koios.rest/api/v1`):
    /// - `c1eaa25a…` (Shelley, epoch 208, block 4494092) by scanning the
    ///   epoch's blocks with `POST /block_tx_info` for `reserve_MIR`
    ///   certificates; it is one of the ITN-reward MIR transactions, with 200
    ///   stake registrations and one MIR certificate paying 200 credentials.
    /// - `8cab8049…` (Mary, epoch 271) and `03b02cff…` (Alonzo, epoch 298)
    ///   from Cardanoscan links in the Cardano Forum thread "Where did the
    ///   Block rewards go?!" (forum.cardano.org/t/84343), confirmed as MIR
    ///   transactions with `POST /tx_info` (`_certs: true`).
    ///
    /// The CBOR in `data/certificate-txs/<id>.hex` is from
    /// `POST /tx_cbor` with `{"_tx_hashes": [id]}`. The expected credentials
    /// and amounts are Koios's decoding of the same certificates (its
    /// `/tx_info` `certificates`), an oracle independent of this package.
    struct MIRTransaction: Sendable, CustomTestStringConvertible {
        var id: String
        var era: Era
        var registrations: Int
        var entries: Int
        var total: BigInt
        /// Some of the credentials paid (key hashes) and their amounts.
        var expected: [String: BigInt]

        var testDescription: String { "\(era) \(id.prefix(12))" }

        func bytes() throws -> Data {
            let url = try #require(
                Bundle.module.resourceURL?.appendingPathComponent("data/certificate-txs/\(id).hex"))
            let hex = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return try #require(Data(hexString: hex))
        }
    }

    static let mirTransactions: [MIRTransaction] = [
        MIRTransaction(
            id: "c1eaa25a9f4c20d4f36f8016715236bbb66e07ea89573dc47c47163807be5034",
            era: .shelley, registrations: 200, entries: 200, total: 4_139_016_331_433,
            expected: [
                "006a4f4ee877e09203c38e338dbf73cd6e42d091474980976f716b00": 2_354_089_557,
                "06b94f11853a8bdcfbe796aa052b96fb921d8353fdd2c0ca67b7a069": 54_494_804_431,
                "07749afe35c81f764e86c2f5ef78e8358d6bcf065d98c6a5b340db35": 87_225_886,
                "fe27db271d4eda7220c56f774223c0ac311e18a0d20093228ea2df9d": 58_052_551_661,
            ]),
        MIRTransaction(
            id: "8cab8049e3b8c4802d7d11277b21afc74056223a596c39ef00e002c2d1f507ad",
            era: .mary, registrations: 4, entries: 4, total: 369_638_518,
            expected: [
                "0af10f4a5d365af01f0ca7651713a8a073263b61bbd1f69623097bd7": 264_920_313,
                "14bb4165052cb5bd0ca51869db388610c9ee92ca67e44a239759d059": 80_189_160,
                "854139fc8987990fd89699beb1b59b09c047ace356870dcaadc93b22": 5_415_462,
                "d5b9ca34735343fcfc01d804180c8cfd20c45df317c44dec278ecdf6": 19_113_583,
            ]),
        MIRTransaction(
            id: "03b02cff29a5f2dfc827e00345eaab8b29a3d740e9878aa6e5dd2b52da0763c5",
            era: .alonzo, registrations: 0, entries: 6, total: 318_199_980_000_000,
            expected: [
                "0fa8268618b0142a786b6c21684ac755ba14109f2a03746f3a0a3659": 66_000_000_000_000,
                "2ce8503b748d65b6ffb09e1ee238e291c7693224142ef67b6e5da30e": 66_000_000_000_000,
                "764dcf557b2859c76e225b04517a27235e2cbc4b093eb2137e4957f1": 27_099_990_000_000,
                "cfe90c9f6b7177b2f56aac6f2aeae98ebf7720a944cd8c95415d8955": 27_099_990_000_000,
                "de4f7a524e1a4dae27eed119f4aea86ad3952976b46042016ba1d540": 66_000_000_000_000,
                "ec8c25a1ca4734d29e7b2bedf664220f4942ff1a2a155c70345cd807": 66_000_000_000_000,
            ]),
    ]

    @Test("Mainnet MIR transactions decode, keep their id, and re-encode", arguments: mirTransactions)
    func mainnetMIR(_ entry: MIRTransaction) throws {
        let bytes = try entry.bytes()
        let tx = try Transaction.fromCBOR(data: bytes, era: entry.era)

        #expect(tx.id?.payload.toHex == entry.id)
        #expect(tx.transactionBody.hash().toHex == entry.id)
        #expect(try tx.toCBORData() == bytes)

        let certificates = try #require(tx.transactionBody.certificates).asList
        let written = try Self.certificateBytes(inBody: try Self.bodyBytes(ofTransaction: bytes))
        try Self.expectCertificatesRoundTrip(certificates, written: written)

        // The body encoded afresh, not from its kept bytes, is the same too.
        var rebuilt = tx.transactionBody
        let certificateSet = rebuilt.certificates
        rebuilt.certificates = certificateSet  // clears the kept bytes
        #expect(try rebuilt.toCBORData() == (try Self.bodyBytes(ofTransaction: bytes)))

        var registrations = 0
        var mirs: [MoveInstantaneousReward] = []
        for certificate in certificates {
            switch certificate {
            case .stakeRegistration: registrations += 1
            case .moveInstantaneousRewards(let mir): mirs.append(mir.moveInstantaneousRewards)
            default: Issue.record("unexpected certificate \(certificate)")
            }
        }
        #expect(registrations == entry.registrations)
        let mir = try #require(mirs.first)
        #expect(mirs.count == 1)
        #expect(mir.source == .reserves)
        #expect(mir.coin == nil)
        let rewards = try #require(mir.rewards)
        #expect(rewards.count == entry.entries)
        #expect(rewards.values.reduce(0, +) == entry.total)
        var byHash: [String: BigInt] = [:]
        for (credential, delta) in rewards {
            guard case let .verificationKeyHash(hash) = credential.credential else {
                Issue.record("expected key-hash credentials"); continue
            }
            byHash[hash.payload.toHex] = delta
        }
        for (hash, amount) in entry.expected {
            #expect(byHash[hash] == amount, "credential \(hash)")
        }
    }

    // MARK: - Every certificate in the transaction corpus

    struct CorpusEntry: Sendable, CustomTestStringConvertible {
        var era: Era
        var directory: String
        var hash: String
        var testDescription: String { "\(directory)/\(hash.prefix(12))" }
    }

    /// The corpus transactions (see `TransactionCorpusTests`) that carry
    /// certificates: pool registrations and retirements, stake registrations
    /// and delegations, DRep registrations, updates and retirements, vote
    /// delegations.
    static let corpusWithCertificates: [CorpusEntry] = {
        let eras: [(String, Era)] = [
            ("shelley", .shelley), ("allegra", .allegra), ("mary", .mary),
            ("alonzo", .alonzo), ("babbage", .babbage), ("conway", .conway),
        ]
        let features = ["pool-reg", "pool-retire", "stake-reg", "stake-deleg", "drep-reg",
                        "drep-update", "drep-unreg", "vote-deleg"]
        return eras.flatMap { directory, era -> [CorpusEntry] in
            guard let url = Bundle.module.resourceURL?
                    .appendingPathComponent("data/tx-corpus/\(directory)/MANIFEST.tsv"),
                  let manifest = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return manifest.split(separator: "\n").dropFirst().compactMap { line in
                let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 5,
                      fields[4].split(separator: ",").contains(where: { features.contains(String($0)) })
                else { return nil }
                return CorpusEntry(era: era, directory: directory, hash: fields[0])
            }
        }
    }()

    @Test("The corpus has certificate transactions")
    func corpusHasCertificates() {
        #expect(Self.corpusWithCertificates.count >= 15)
    }

    @Test("Corpus certificates re-encode to their written bytes", arguments: corpusWithCertificates)
    func corpusCertificates(_ entry: CorpusEntry) throws {
        let url = try #require(Bundle.module.resourceURL?
            .appendingPathComponent("data/tx-corpus/\(entry.directory)/\(entry.hash).hex"))
        let hex = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = try #require(Data(hexString: hex))
        let tx = try Transaction.fromCBOR(data: bytes, era: entry.era)
        #expect(tx.id?.payload.toHex == entry.hash)

        let certificates = try #require(tx.transactionBody.certificates).asList
        let written = try Self.certificateBytes(inBody: try Self.bodyBytes(ofTransaction: bytes))
        try Self.expectCertificatesRoundTrip(certificates, written: written)
    }

    // MARK: - CDDL-built vectors

    static let keyCredential = "8200581c" + repeated("11", 28)
    static let scriptCredential = "8201581c" + repeated("22", 28)
    static let poolKeyHash = "581c" + repeated("33", 28)
    static let anchor = "82" + "6b" + "68747470733a2f2f612e62" + "5820" + repeated("44", 32)  // ["https://a.b", h'44…']
    static let maxCoin = "1bffffffffffffffff"

    /// One of each certificate kind the Conway CDDL allows, with both
    /// credential kinds, every DRep kind, and anchors present and absent.
    static let cddlVectors: [String] = [
        "8200" + keyCredential,                                     // account_registration_cert
        "8200" + scriptCredential,
        "8201" + scriptCredential,                                  // account_unregistration_cert
        "8302" + scriptCredential + poolKeyHash,                    // delegation_to_stake_pool_cert
        "8304" + poolKeyHash + "1b0000000100000000",                // pool_retirement_cert
        "8307" + scriptCredential + "1a001e8480",                   // account_registration_deposit_cert
        "8308" + keyCredential + maxCoin,                           // account_unregistration_deposit_cert
        "8309" + keyCredential + "8200581c" + repeated("55", 28),   // delegation_to_drep_cert, key DRep
        "8309" + keyCredential + "8201581c" + repeated("55", 28),   // script DRep
        "8309" + scriptCredential + "8102",                         // always abstain
        "8309" + keyCredential + "8103",                            // always no confidence
        "840a" + scriptCredential + poolKeyHash + "8103",           // delegation_to_stake_pool_and_drep_cert
        "840b" + scriptCredential + poolKeyHash + "00",             // account_registration_delegation_to_stake_pool_cert
        "840c" + scriptCredential + "8201581c" + repeated("55", 28) + "1a001e8480",
        "850d" + keyCredential + poolKeyHash + "8102" + "1a001e8480",
        "830e" + keyCredential + scriptCredential,                  // committee_authorization_cert
        "830e" + scriptCredential + keyCredential,
        "830f" + scriptCredential + "f6",                           // committee_resignation_cert
        "830f" + keyCredential + anchor,
        "8410" + scriptCredential + "1a1dcd6500" + "f6",            // drep_registration_cert
        "8410" + keyCredential + "1a1dcd6500" + anchor,
        "8311" + scriptCredential + "1a1dcd6500",                   // drep_unregistration_cert
        "8312" + keyCredential + "f6",                              // drep_update_cert
        "8312" + scriptCredential + anchor,
    ]

    @Test("Conway CDDL certificates decode and re-encode", arguments: cddlVectors)
    func cddlCertificate(_ hex: String) throws {
        let bytes = try #require(Data(hexString: hex))
        let certificate = try Certificate.fromCBOR(data: bytes)
        #expect(try certificate.toCBORHex() == hex)
        try Self.expectCertificatesRoundTrip([certificate], written: [bytes])
    }

    @Test("Certificates with the wrong shape throw")
    func malformedCertificates() throws {
        let malformed = [
            "820f" + Self.keyCredential,                              // resignation without its anchor
            "830f" + Self.keyCredential + "82" + "6b68747470733a2f2f612e62" + "4100",  // anchor hash too short
            "8410" + Self.keyCredential + "00" + "a0",                // anchor that is a map
            "8312" + Self.keyCredential + "00",                       // anchor that is a number
            "8300" + Self.keyCredential + "00",                       // extra field
            "8320" + Self.keyCredential + "00",                       // negative code
            "8201" + "8202581c" + Self.repeated("11", 28),            // credential kind 2
            "8302" + Self.keyCredential + "581b" + Self.repeated("33", 27),  // 27-byte pool key hash
            "8307" + Self.keyCredential + "20",                       // negative deposit
            "8213" + Self.keyCredential,                              // code 19
        ]
        for hex in malformed {
            #expect(throws: (any Error).self, "\(hex)") { try Certificate.fromCBORHex(hex) }
        }
    }

    // MARK: - Genesis key delegation

    // No genesis key delegation certificate could be found on mainnet:
    // cardano-db-sync, and so Koios, does not index them, and none of the
    // MIR-era scans above turned one up. These vectors are built from the
    // CDDL instead: `genesis_delegation_cert = (5, genesis_hash,
    // genesis_delegate_hash, vrf_keyhash)` with 28-byte genesis and delegate
    // hashes and a 32-byte VRF key hash.
    static let genesisDelegationHex = "8405"
        + "581c" + repeated("a1", 28) + "581c" + repeated("b2", 28) + "5820" + repeated("c3", 32)

    @Test("A genesis key delegation decodes and re-encodes")
    func genesisKeyDelegation() throws {
        let bytes = try #require(Data(hexString: Self.genesisDelegationHex))
        let certificate = try Certificate.fromCBOR(data: bytes)
        guard case let .genesisKeyDelegation(delegation) = certificate else {
            Issue.record("expected a genesis key delegation"); return
        }
        #expect(delegation.genesisHash.payload.toHex == Self.repeated("a1", 28))
        #expect(delegation.genesisDelegateHash.payload.toHex == Self.repeated("b2", 28))
        #expect(delegation.vrfKeyHash.payload.toHex == Self.repeated("c3", 32))
        #expect(delegation.payload == bytes)
        #expect(try certificate.toCBORData() == bytes)
        try Self.expectCertificatesRoundTrip([certificate], written: [bytes])

        let envelope = try #require(try delegation.toTextEnvelope())
        let restored = try GenesisKeyDelegation.fromTextEnvelope(envelope)
        #expect(restored.payload == bytes)
        #expect(try GenesisKeyDelegation(payload: bytes, type: nil, description: nil).payload == bytes)

        // A 32-byte genesis hash (the size of a block hash) is not a genesis hash.
        let wrongSize = "8405" + "5820" + Self.repeated("a1", 32) + "581c" + Self.repeated("b2", 28)
            + "5820" + Self.repeated("c3", 32)
        #expect(throws: (any Error).self) { try Certificate.fromCBORHex(wrongSize) }
        #expect(throws: (any Error).self) {
            try Certificate.fromCBORHex("8305" + "581c" + Self.repeated("a1", 28) + "581c" + Self.repeated("b2", 28))
        }
    }

    // MARK: - MIR CDDL vectors

    @Test("MIR certificates of every form decode and re-encode")
    func mirForms() throws {
        let toCredentials = "8206" + "8201" + "a2"
            + Self.scriptCredential + "3903e7"       // -1000
            + Self.keyCredential + "1a000f4240"      // 1000000
        let toOtherPotFromReserves = "8206" + "8200" + "1b000000e8d4a51000"
        let toOtherPotFromTreasury = "8206" + "8201" + "00"
        let emptyMap = "8206" + "8200" + "a0"

        for hex in [toCredentials, toOtherPotFromReserves, toOtherPotFromTreasury, emptyMap] {
            let bytes = try #require(Data(hexString: hex))
            let certificate = try Certificate.fromCBOR(data: bytes)
            #expect(try certificate.toCBORHex() == hex)
            try Self.expectCertificatesRoundTrip([certificate], written: [bytes])
        }

        guard case let .moveInstantaneousRewards(cert) = try Certificate.fromCBORHex(toCredentials) else {
            Issue.record("expected a MIR certificate"); return
        }
        let mir = cert.moveInstantaneousRewards
        #expect(mir.source == .treasury)
        let rewards = try #require(mir.rewards)
        // The map keeps the order it was written in.
        #expect(rewards.keys.map(\.credential) == [
            .scriptHash(ScriptHash(payload: Data(repeating: 0x22, count: 28))),
            .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0x11, count: 28))),
        ])
        #expect(Array(rewards.values) == [-1000, 1_000_000])

        guard case let .moveInstantaneousRewards(pot) = try Certificate.fromCBORHex(toOtherPotFromReserves) else {
            Issue.record("expected a MIR certificate"); return
        }
        #expect(pot.moveInstantaneousRewards.source == .reserves)
        #expect(pot.moveInstantaneousRewards.coin == 1_000_000_000_000)
        #expect(pot.moveInstantaneousRewards.rewards == nil)

        // The text envelope keeps the certificate.
        let envelope = try #require(try cert.toTextEnvelope())
        #expect(try MoveInstantaneousRewards.fromTextEnvelope(envelope).moveInstantaneousRewards == mir)

        // An indefinite-length map, as the Shelley ledger wrote it (in its
        // key order: script hashes first), decodes and re-encodes as written.
        let indefinite = "8206" + "8200" + "bf" + Self.scriptCredential + "02" + Self.keyCredential + "01" + "ff"
        let indefiniteBytes = try #require(Data(hexString: indefinite))
        let readCertificate = try Certificate.fromCBOR(data: indefiniteBytes)
        guard case let .moveInstantaneousRewards(read) = readCertificate else {
            Issue.record("expected a MIR certificate"); return
        }
        #expect(read.moveInstantaneousRewards.indefiniteLengthMap)
        #expect(read.moveInstantaneousRewards.rewards?.count == 2)
        try Self.expectCertificatesRoundTrip([readCertificate], written: [indefiniteBytes])

        // A built certificate encodes as the CDDL says.
        let built = try MoveInstantaneousRewards(moveInstantaneousRewards: MoveInstantaneousReward(
            source: .treasury,
            rewards: [
                StakeCredential(credential: .scriptHash(ScriptHash(payload: Data(repeating: 0x22, count: 28)))): -1000,
                StakeCredential(credential: .verificationKeyHash(
                    VerificationKeyHash(payload: Data(repeating: 0x11, count: 28)))): 1_000_000,
            ]))
        #expect(built.payload.toHex == toCredentials)
        #expect(try built.toCBORHex() == toCredentials)
    }

    @Test("Malformed MIR certificates throw")
    func malformedMIR() throws {
        let malformed = [
            "8206" + "8202" + "00",                               // pot 2
            "8206" + "8300" + "a0" + "00",                        // three fields
            "8206" + "8200" + "20",                               // negative coin to the other pot
            "8206" + "8200" + "a1" + Self.keyCredential + "f6",   // null delta
            "8206" + "8200" + "a1" + "00" + "01",                 // key that is not a credential
            "8306" + "8200" + "00" + "00",                        // extra certificate field
        ]
        for hex in malformed {
            #expect(throws: (any Error).self, "\(hex)") { try Certificate.fromCBORHex(hex) }
        }
    }

    // MARK: - Dict round trips of stake-credential certificates

    @Test("Stake-credential certificates round-trip through their dict form")
    func stakeCredentialDicts() throws {
        let script = StakeCredential(credential: .scriptHash(ScriptHash(payload: Data(repeating: 0x22, count: 28))))
        let key = StakeCredential(credential: .verificationKeyHash(
            VerificationKeyHash(payload: Data(repeating: 0x11, count: 28))))
        let pool = PoolKeyHash(payload: Data(repeating: 0x33, count: 28))
        let drep = DRep(credential: .scriptHash(ScriptHash(payload: Data(repeating: 0x55, count: 28))))

        for credential in [script, key] {
            let registration = try StakeRegistration(stakeCredential: credential)
            #expect(try StakeRegistration.fromDict(try registration.toDict()) == registration)
            let deregistration = try StakeDeregistration(stakeCredential: credential)
            #expect(try StakeDeregistration.fromDict(try deregistration.toDict()) == deregistration)
            let delegation = try StakeDelegation(stakeCredential: credential, poolKeyHash: pool)
            #expect(try StakeDelegation.fromDict(try delegation.toDict()) == delegation)
            let register = try Register(stakeCredential: credential, coin: .max)
            #expect(try Register.fromDict(try register.toDict()) == register)
            let unregister = try Unregister(stakeCredential: credential, coin: 2_000_000)
            #expect(try Unregister.fromDict(try unregister.toDict()) == unregister)
            let vote = try VoteDelegate(stakeCredential: credential, drep: drep)
            #expect(try VoteDelegate.fromDict(try vote.toDict()) == vote)
            let stakeVote = try StakeVoteDelegate(stakeCredential: credential, poolKeyHash: pool, drep: drep)
            #expect(try StakeVoteDelegate.fromDict(try stakeVote.toDict()) == stakeVote)
            let regDeleg = try StakeRegisterDelegate(stakeCredential: credential, poolKeyHash: pool, coin: 1)
            #expect(try StakeRegisterDelegate.fromDict(try regDeleg.toDict()) == regDeleg)
            let voteReg = try VoteRegisterDelegate(stakeCredential: credential, drep: drep, coin: 1)
            #expect(try VoteRegisterDelegate.fromDict(try voteReg.toDict()) == voteReg)
            let all = try StakeVoteRegisterDelegate(stakeCredential: credential, poolKeyHash: pool, drep: drep, coin: 1)
            #expect(try StakeVoteRegisterDelegate.fromDict(try all.toDict()) == all)
        }

        // The dict says which kind of credential it holds.
        let dict = try StakeRegistration(stakeCredential: script).toDict()
        #expect(dict == .orderedDict([
            .string("stakeCredential"): .orderedDict([.string("scriptHash"): .string(Self.repeated("22", 28))]),
        ]))
        // A bare hex string is ambiguous between the kinds and is refused.
        #expect(throws: (any Error).self) {
            try StakeRegistration.fromDict(.orderedDict([.string("stakeCredential"): .string(Self.repeated("22", 28))]))
        }
    }
}
