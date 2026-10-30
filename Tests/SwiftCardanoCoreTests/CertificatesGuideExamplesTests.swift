import Foundation
import Testing
import SwiftCardanoCore

/// The code examples of the Certificates guide (`Certificates.md`), compiled
/// and run so that the guide stays true to the API. Each test holds one
/// example as the guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Certificates guide examples")
struct CertificatesGuideExamplesTests {
    // Stand-ins for values the guide assumes, or that earlier examples build.
    let stakeKeyPair = try! StakeKeyPair.generate()
    var stakeCredential: StakeCredential {
        StakeCredential(credential: .verificationKeyHash(try! stakeKeyPair.verificationKey.hash()))
    }
    let poolKeyPair = try! StakePoolKeyPair.generate()
    var poolKeyHash: PoolKeyHash { try! poolKeyPair.verificationKey.poolKeyHash() }
    let drepKeyPair = try! DRepKeyPair.generate()
    var certificate: Certificate {
        .register(try! Register(stakeCredential: stakeCredential, coin: Coin(2_000_000)))
    }
    var delegationCert: Certificate {
        .stakeDelegation(try! StakeDelegation(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash))
    }
    var voteDelegationCert: Certificate {
        .voteDelegate(try! VoteDelegate(
            stakeCredential: stakeCredential, drep: DRep(credential: .alwaysAbstain)))
    }
    var certificates: [Certificate] { [certificate, delegationCert, voteDelegationCert] }
    let txInput = TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)
    var txOutput: TransactionOutput {
        TransactionOutput(
            address: try! Address(
                paymentPart: .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 3, count: 28))),
                network: .testnet),
            amount: Value(coin: 2_000_000))
    }

    @Test func stakeRegistration() throws {
        // Generate stake keys
        let stakeKeyPair = try StakeKeyPair.generate()

        // Create stake credential
        let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()))

        // Create registration certificate (Conway: the certificate states the deposit)
        let stakeRegistration = try Register(
            stakeCredential: stakeCredential,
            coin: Coin(2_000_000) // Registration deposit (2 ADA)
        )

        let certificate = Certificate.register(stakeRegistration)

        // The Shelley-era certificate leaves the deposit to the protocol parameters
        let legacyRegistration = Certificate.stakeRegistration(try StakeRegistration(stakeCredential: stakeCredential))
        _ = try (certificate.toCBORData(), legacyRegistration.toCBORData())
    }

    @Test func stakeDelegation() throws {
        // Pool ID to delegate to
        let poolOperator = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")

        // Create delegation certificate
        let stakeDelegation = try StakeDelegation(
            stakeCredential: stakeCredential,
            poolKeyHash: poolOperator.poolKeyHash
        )

        let delegationCert = Certificate.stakeDelegation(stakeDelegation)
        _ = try delegationCert.toCBORData()
    }

    @Test func combinedRegistrationAndDelegation() throws {
        // Modern approach: register and delegate in one certificate
        let stakeRegisterDelegate = try StakeRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            coin: Coin(2_000_000) // Registration deposit
        )

        let combinedCert = Certificate.stakeRegisterDelegate(stakeRegisterDelegate)
        _ = try combinedCert.toCBORData()
    }

    @Test func poolRegistration() throws {
        // Generate pool keys
        let poolKeyPair = try StakePoolKeyPair.generate()
        let vrfKeyPair = try VRFKeyPair.generate()

        // Pool metadata: where the metadata file is, and its hash
        let poolMetadata = try PoolMetadata(
            url: try Url("https://example.com/pool-metadata.json"),
            poolMetadataHash: PoolMetadataHash(payload: Data(repeating: 0x01, count: 32))
        )

        // The reward account: the bytes of the operator's stake address
        let rewardAddress = try Address(
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .mainnet
        )

        // Pool parameters
        let poolParams = PoolParams(
            poolOperator: try poolKeyPair.verificationKey.poolKeyHash(),
            vrfKeyHash: try vrfKeyPair.verificationKey.hash(),
            pledge: Coin(100_000_000_000), // 100,000 ADA
            cost: Coin(340_000_000), // 340 ADA minimum
            margin: UnitInterval(numerator: 3, denominator: 100), // 3% margin
            rewardAccount: RewardAccountHash(payload: rewardAddress.toBytes()),
            poolOwners: .list([try stakeKeyPair.verificationKey.hash()]),
            relays: [], // Add relay information as needed
            poolMetadata: poolMetadata
        )

        // Create pool registration certificate
        let poolRegistration = try PoolRegistration(poolParams: poolParams)
        let poolRegCert = Certificate.poolRegistration(poolRegistration)
        _ = try poolRegCert.toCBORData()
    }

    @Test func poolRetirement() throws {
        // Retire pool at specific epoch
        let poolRetirement = try PoolRetirement(
            poolKeyHash: try poolKeyPair.verificationKey.poolKeyHash(),
            epoch: 350 // Retirement epoch
        )

        let poolRetireCert = Certificate.poolRetirement(poolRetirement)
        _ = try poolRetireCert.toCBORData()
    }

    @Test func drepRegistration() throws {
        // Generate DRep keys
        let drepKeyPair = try DRepKeyPair.generate()

        // Create DRep registration certificate
        let drepRegistration = try RegisterDRep(
            drepCredential: DRepCredential(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash())),
            coin: Coin(500_000_000), // DRep deposit (500 ADA)
            anchor: Anchor(
                anchorUrl: try Url("https://example.com/drep-metadata.json"),
                anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x03, count: 32))
            )
        )

        let drepRegCert = Certificate.registerDRep(drepRegistration)
        _ = try drepRegCert.toCBORData()
    }

    @Test func voteDelegation() throws {
        // Delegate voting power to a DRep
        let voteDelegation = try VoteDelegate(
            stakeCredential: stakeCredential,
            drep: DRep(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash()))
        )

        let voteDelegationCert = Certificate.voteDelegate(voteDelegation)

        // Alternative: delegate to always abstain
        let alwaysAbstainDelegation = try VoteDelegate(
            stakeCredential: stakeCredential,
            drep: DRep(credential: .alwaysAbstain)
        )

        let abstainCert = Certificate.voteDelegate(alwaysAbstainDelegation)
        _ = try (voteDelegationCert.toCBORData(), abstainCert.toCBORData())
    }

    @Test func multipleCertificatesInTransaction() throws {
        // Create transaction with multiple certificates
        let certificates: [Certificate] = [
            certificate, // Stake registration
            delegationCert, // Stake delegation
            voteDelegationCert // Vote delegation
        ]

        let txBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([txInput])),
            outputs: [txOutput],
            fee: Coin(500_000), // Higher fee for multiple certificates
            certificates: .nonEmptyOrderedSet(NonEmptyOrderedSet(certificates))
        )
        _ = try txBody.toCBORData()
    }

    @Test func cborEncoding() throws {
        // Serialize individual certificate
        let cborData = try certificate.toCBORData()
        let cborHex = try certificate.toCBORHex()

        // Serialize a list of certificates
        let certificatesData = try ListOrNonEmptyOrderedSet.list(certificates).toCBORData()
        _ = (cborData, cborHex, certificatesData)
    }

    @Test(.disabled("Writes certificate files to the working directory"))
    func saveAndLoadMethods() throws {
        // Create a certificate
        let stakeKeyPair = try StakeKeyPair.generate()
        let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()))
        let stakeRegistration = try Register(
            stakeCredential: stakeCredential,
            coin: Coin(2_000_000)
        )

        // Save certificate to file
        try stakeRegistration.save(to: "stake-registration.cert")
        print("Certificate saved to stake-registration.cert")

        // Load certificate from file
        let loadedCertificate = try Register.load(from: "stake-registration.cert")
        print("Certificate loaded successfully")

        // Verify they match
        #expect(stakeRegistration == loadedCertificate)
    }

    @Test(.disabled("Writes certificate files to the working directory"))
    func fileFormatCompatibility() throws {
        // Save different certificate types
        let poolOperator = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")
        let delegationCert = try StakeDelegation(
            stakeCredential: stakeCredential,
            poolKeyHash: poolOperator.poolKeyHash
        )

        let drepKeyPair = try DRepKeyPair.generate()
        let drepCert = try RegisterDRep(
            drepCredential: DRepCredential(credential: .verificationKeyHash(try drepKeyPair.verificationKey.hash())),
            coin: Coin(500_000_000),
            anchor: Anchor(
                anchorUrl: try Url("https://example.com/drep-metadata.json"),
                anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x03, count: 32))
            )
        )

        // Save certificates to files
        try delegationCert.save(to: "stake-delegation.cert")
        try drepCert.save(to: "drep-registration.cert")

        // These files can be used directly with cardano-cli commands
    }

    @Test(.disabled("Writes a certificate file to the working directory"))
    func errorHandlingWithFileOperations() throws {
        let stakeRegistration = try Register(stakeCredential: stakeCredential, coin: Coin(2_000_000))

        do {
            // Save certificate
            try stakeRegistration.save(to: "my-certificate.cert")

            // Load certificate
            let loadedCert = try Register.load(from: "my-certificate.cert")
            print("Certificate loaded successfully: \(loadedCert.description)")

        } catch CardanoCoreError.ioError(let message) {
            print("File operation failed: \(message ?? "")")
        } catch CardanoCoreError.deserializeError(let message) {
            print("Certificate parsing failed: \(message ?? "")")
        } catch {
            print("Certificate file operation failed: \(error)")
        }
    }

    /// The file example's cases are the ones `save(to:)` and `load(from:)`
    /// throw; run here in a temporary directory.
    @Test func errorHandlingWithFileOperationsCatchesEachCase() throws {
        let directory = NSTemporaryDirectory() + "certificates-guide-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let stakeRegistration = try Register(stakeCredential: stakeCredential, coin: Coin(2_000_000))
        let path = directory + "my-certificate.cert"

        // Saving over an existing file
        try stakeRegistration.save(to: path)
        #expect(throws: CardanoCoreError.ioError("File already exists: \(path)")) {
            try stakeRegistration.save(to: path)
        }
        #expect(try Register.load(from: path) == stakeRegistration)

        // Loading a file that is not there
        let missing = #expect(throws: CardanoCoreError.self) {
            try Register.load(from: directory + "missing.cert")
        }
        guard case .ioError = missing else {
            Issue.record("Expected ioError, got \(String(describing: missing))")
            return
        }

        // Loading another kind of certificate
        let error = #expect(throws: CardanoCoreError.self) {
            try Unregister.load(from: path)
        }
        guard case .deserializeError = error else {
            Issue.record("Expected deserializeError, got \(String(describing: error))")
            return
        }
    }
}
