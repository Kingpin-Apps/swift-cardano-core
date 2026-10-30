import Foundation
import Testing
import SwiftCardanoCore

/// The code examples of the Stake Pools guide (`StakePools.md`), compiled and
/// run so that the guide stays true to the API. Each test holds one example
/// as the guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Stake Pools guide examples")
struct StakePoolsGuideExamplesTests {
    // Stand-ins for values the guide assumes, or that earlier examples build.
    let coldKeyPair = try! StakePoolKeyPair.generate()
    let kesKeyPair = try! KESKeyPair.generate()
    let vrfKeyPair = try! VRFKeyPair.generate()
    var poolKeyHash: PoolKeyHash { try! coldKeyPair.verificationKey.poolKeyHash() }
    let kesPeriod: UInt64 = 0
    let metadataHashBytes = Data(repeating: 0x01, count: 32)
    let ipv4Address = IPv4Address("192.0.2.1")!
    let ownerKeyHash = VerificationKeyHash(payload: Data(repeating: 2, count: 28))
    let rewardAccountHash = RewardAccountHash(payload: Data([0xE1]) + Data(repeating: 2, count: 28))

    func newIssueCounter() throws -> OperationalCertificateIssueCounter {
        try OperationalCertificateIssueCounter.createNewCounter(coldVerificationKey: coldKeyPair.verificationKey)
    }

    @Test(.disabled("Writes key files to the working directory"))
    func generateColdKeys() throws {
        // Generate cold key pair
        let coldKeyPair = try StakePoolKeyPair.generate()

        // Save keys in Cardano CLI-compatible format
        try coldKeyPair.signingKey.save(to: "cold.skey")
        try coldKeyPair.verificationKey.save(to: "cold.vkey")

        // Derive the pool ID
        let poolKeyHash = try coldKeyPair.verificationKey.poolKeyHash()
        let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
        print("Pool ID: \(try poolOperator.toBech32())")
    }

    @Test(.disabled("Writes key files to the working directory"))
    func generateKESKeys() throws {
        // Generate KES key pair
        let kesKeyPair = try KESKeyPair.generate()

        // Save keys
        try kesKeyPair.signingKey.save(to: "kes.skey")
        try kesKeyPair.verificationKey.save(to: "kes.vkey")

        // KES keys support 64 signing periods (Sum6KES depth 6)
        print("Total KES periods: \(KESSigningKey.totalPeriods)") // 64
    }

    @Test(.disabled("Writes key files to the working directory"))
    func generateVRFKeys() throws {
        // Generate VRF key pair
        let vrfKeyPair = try VRFKeyPair.generate()

        // Save keys
        try vrfKeyPair.signingKey.save(to: "vrf.skey")
        try vrfKeyPair.verificationKey.save(to: "vrf.vkey")

        // Get VRF key hash for pool registration
        let vrfKeyHash = try vrfKeyPair.verificationKey.hash()
        _ = vrfKeyHash
    }

    @Test(.disabled("Writes the counter file to the working directory"))
    func createIssueCounter() throws {
        // Create a new counter (starts at 0)
        var issueCounter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: coldKeyPair.verificationKey
        )

        // Save in Cardano CLI-compatible format
        try issueCounter.save(to: "opcert.counter")

        // Load an existing counter
        let loadedCounter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")
        try issueCounter.increment() // as issuing a certificate, the next step, does
        _ = loadedCounter
    }

    @Test(.disabled("Writes the certificate files to the working directory"))
    func issueAnOperationalCertificate() throws {
        var issueCounter = try newIssueCounter()

        // Issue a new operational certificate
        let kesPeriod: UInt64 = 0 // Current KES period

        let opcert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey,
            coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &issueCounter,
            kesPeriod: kesPeriod
        )

        // Save the certificate and updated counter
        try opcert.save(to: "node.cert")
        try issueCounter.save(to: "opcert.counter", overwrite: true)

        // The counter was automatically incremented
        print("Next sequence number: \(issueCounter.counterValue)") // 1
    }

    @Test(.disabled("Reads and writes node files in the working directory"))
    func keyRotation() throws {
        // 1. Generate new KES keys
        let newKesKeyPair = try KESKeyPair.generate()
        try newKesKeyPair.signingKey.save(to: "kes.skey", overwrite: true)
        try newKesKeyPair.verificationKey.save(to: "kes.vkey", overwrite: true)

        // 2. Generate new VRF keys
        let newVrfKeyPair = try VRFKeyPair.generate()
        try newVrfKeyPair.signingKey.save(to: "vrf.skey", overwrite: true)
        try newVrfKeyPair.verificationKey.save(to: "vrf.vkey", overwrite: true)

        // 3. Load the existing counter and cold signing key
        var counter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")
        let coldSKey = try StakePoolSigningKey.load(from: "cold.skey")

        // 4. Issue a new operational certificate with the new KES key
        let currentKesPeriod: UInt64 = 64 // The KES period at rotation time
        let newCert = try OperationalCertificate.issue(
            kesVerificationKey: newKesKeyPair.verificationKey,
            coldSigningKey: coldSKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: currentKesPeriod
        )

        // 5. Save the new certificate and updated counter
        try newCert.save(to: "node.cert", overwrite: true)
        try counter.save(to: "opcert.counter", overwrite: true)

        // 6. Restart the node with the new files
    }

    @Test func configurePoolParameters() throws {
        // Pool metadata (hosted off-chain)
        let poolMetadata = try PoolMetadata(
            url: Url("https://example.com/pool-metadata.json"),
            poolMetadataHash: PoolMetadataHash(payload: metadataHashBytes)
        )

        // Configure relay endpoints
        let relay = Relay.singleHostAddr(
            SingleHostAddr(port: 6000, ipv4: IPv4Address("192.0.2.1"), ipv6: nil)
        )

        // Build pool parameters
        let poolParams = PoolParams(
            poolOperator: try coldKeyPair.verificationKey.poolKeyHash(),
            vrfKeyHash: try vrfKeyPair.verificationKey.hash(),
            pledge: 100_000_000_000, // 100,000 ADA in lovelace
            cost: 340_000_000,       // 340 ADA minimum cost
            margin: UnitInterval(numerator: 3, denominator: 100), // 3% margin
            rewardAccount: rewardAccountHash,
            poolOwners: .orderedSet(try OrderedSet([ownerKeyHash])),
            relays: [relay],
            poolMetadata: poolMetadata
        )
        _ = try poolParams.toCBORData()
    }

    @Test func poolMetadata() throws {
        // Create pool metadata for off-chain hosting
        let metadata = try PoolMetadata(
            name: "My Stake Pool",
            description: "A reliable Cardano stake pool",
            ticker: "MYSP",
            homepage: Url("https://example.com")
        )

        // Compute the metadata hash (must be under 512 bytes)
        let metadataHash = try metadata.hash()
        print("Metadata hash: \(metadataHash)")

        // Serialize to JSON for hosting
        let json = try metadata.toJSON()
        _ = json
    }

    @Test func poolOperatorIdentity() throws {
        // Create from bech32 pool ID
        let poolOp = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")

        // Create from key hash
        let poolOpFromHash = try PoolOperator(from: poolKeyHash.payload)

        // Get pool ID in different formats
        let bech32Id = try poolOp.toBech32()
        let hexId = try poolOp.id(.hex)

        // Validate a pool ID
        let isValid = PoolOperator.isValidBech32("pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")
        #expect(isValid)
        _ = (poolOpFromHash, bech32Id, hexId)
    }

    @Test(.disabled("Writes pool.id to the working directory"))
    func poolOperatorIdentityFiles() throws {
        let poolOp = try PoolOperator(from: "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")

        // Save and load pool ID
        try poolOp.save(to: "pool.id", format: .bech32)
        let loaded = try PoolOperator.load(from: "pool.id")
        _ = loaded
    }

    @Test(.disabled("Reads node.cert from the working directory"))
    func loadingAndInspectingCertificates() throws {
        // Load an existing operational certificate
        let cert = try OperationalCertificate.load(from: "node.cert")

        print("KES VKey: \(cert.hotVKey.payload.toHex)")
        print("Sequence: \(cert.sequenceNumber)")
        print("KES Period: \(cert.kesPeriod)")
        print("Sigma: \(cert.sigma.toHex)")

        if let coldVKey = cert.coldVerificationKey {
            print("Cold VKey: \(coldVKey.payload.toHex)")
        }
    }

    @Test func counterValidation() throws {
        let issueCounter = try newIssueCounter()

        // Validate the counter's cold key matches a signing key
        let isValid = issueCounter.validateVerificationKey(coldKeyPair.verificationKey)

        // Inspect counter state
        print("Counter value: \(issueCounter.counterValue)")
        print("Cold VKey: \(issueCounter.coldVerificationKey.payload.toHex)")
        #expect(isValid)
    }

    @Test(.disabled("Writes node files to the working directory"))
    func serializationTextEnvelopes() throws {
        let issueCounter = try newIssueCounter()
        var counter = issueCounter
        let opcert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey, coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter, kesPeriod: kesPeriod)

        // Text envelope save and load (Cardano CLI format)
        try opcert.save(to: "node.cert")
        let loadedCert = try OperationalCertificate.load(from: "node.cert")

        try issueCounter.save(to: "opcert.counter")
        let loadedCounter = try OperationalCertificateIssueCounter.load(from: "opcert.counter")
        _ = (loadedCert, loadedCounter)
    }

    @Test func serializationCBORAndJSON() throws {
        var counter = try newIssueCounter()
        let opcert = try OperationalCertificate.issue(
            kesVerificationKey: kesKeyPair.verificationKey, coldSigningKey: coldKeyPair.signingKey,
            operationalCertificateIssueCounter: &counter, kesPeriod: kesPeriod)

        // CBOR hex encoding
        let cborHex = try opcert.toCBORHex()
        let fromHex = try OperationalCertificate.fromCBORHex(cborHex)

        // JSON, to read or show (the text envelope is the form to read back)
        let json = try opcert.toJSON()
        #expect(fromHex == opcert)
        #expect(json != nil)
    }

    @Test(.disabled("Writes node.cert to the working directory"))
    func errorHandling() throws {
        var issueCounter = try newIssueCounter()

        do {
            let opcert = try OperationalCertificate.issue(
                kesVerificationKey: kesKeyPair.verificationKey,
                coldSigningKey: coldKeyPair.signingKey,
                operationalCertificateIssueCounter: &issueCounter,
                kesPeriod: kesPeriod
            )
            try opcert.save(to: "node.cert")

        } catch {
            print("Operational certificate failed: \(error)")
        }
    }
}
