import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - ByronAddressTests

struct ByronAddressTests {

    // MARK: - Helpers

    /// A 28-byte root used as a fixture throughout these tests.
    private let zeroRoot = Data(repeating: 0x00, count: 28)
    private let oneRoot  = Data(repeating: 0xAB, count: 28)

    // MARK: - ByronAddress.create (round-trip foundation)

    @Test("create: valid pubKey mainnet address round-trips")
    func testCreateMainnetPubKey() async throws {
        let addr = try ByronAddress.create(root: zeroRoot)

        #expect(addr.root == zeroRoot)
        #expect(addr.byronType == .pubKey)
        #expect(addr.attributes.protocolMagic == nil)
        #expect(addr.attributes.derivationPath == nil)
        #expect(addr.network == .mainnet)
    }

    @Test("create: valid testnet address infers testnet from protocolMagic")
    func testCreateTestnetAddress() async throws {
        let attrs = ByronAddressAttributes(protocolMagic: 764824073)
        let addr  = try ByronAddress.create(root: zeroRoot, attributes: attrs, byronType: .pubKey)

        #expect(addr.network == .testnet)
        #expect(addr.attributes.protocolMagic == 764824073)
    }

    @Test("create: all three address sub-types are preserved")
    func testCreateAllByronTypes() async throws {
        for byronType in ByronAddressType.allCases {
            let addr = try ByronAddress.create(root: zeroRoot, byronType: byronType)
            #expect(addr.byronType == byronType)
        }
    }

    @Test("create: derivation path attribute is preserved")
    func testCreateWithDerivationPath() async throws {
        let dp    = Data([0x01, 0x02, 0x03, 0x04])
        let attrs = ByronAddressAttributes(derivationPath: dp)
        let addr  = try ByronAddress.create(root: zeroRoot, attributes: attrs)

        #expect(addr.attributes.derivationPath == dp)
        #expect(addr.attributes.protocolMagic == nil)
    }

    @Test("create: both attributes preserved together")
    func testCreateWithBothAttributes() async throws {
        let dp    = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let attrs = ByronAddressAttributes(derivationPath: dp, protocolMagic: 1)
        let addr  = try ByronAddress.create(root: oneRoot, attributes: attrs, byronType: .redeem)

        #expect(addr.attributes.derivationPath == dp)
        #expect(addr.attributes.protocolMagic == 1)
        #expect(addr.byronType == .redeem)
        #expect(addr.network == .testnet)
    }

    @Test("create: rejects root shorter than 28 bytes")
    func testCreateRejectsShortRoot() async throws {
        #expect(throws: (any Error).self) {
            try ByronAddress.create(root: Data(repeating: 0, count: 27))
        }
    }

    @Test("create: rejects root longer than 28 bytes")
    func testCreateRejectsLongRoot() async throws {
        #expect(throws: (any Error).self) {
            try ByronAddress.create(root: Data(repeating: 0, count: 29))
        }
    }

    // MARK: - Round-trip: bytes

    @Test("round-trip via toBytes / init(from: .bytes)")
    func testRoundTripViaBytes() async throws {
        let original = try ByronAddress.create(
            root: oneRoot,
            attributes: ByronAddressAttributes(protocolMagic: 1),
            byronType: .script
        )
        let bytes   = original.toBytes()
        let parsed  = try ByronAddress(from: .bytes(bytes))

        #expect(parsed == original)
        #expect(parsed.root == original.root)
        #expect(parsed.byronType == original.byronType)
        #expect(parsed.attributes.protocolMagic == original.attributes.protocolMagic)
        #expect(parsed.network == original.network)
    }

    // MARK: - Round-trip: Base58

    @Test("round-trip via toBase58 / fromBase58")
    func testRoundTripViaBase58() async throws {
        let original = try ByronAddress.create(root: zeroRoot)
        let base58   = original.toBase58()

        #expect(!base58.isEmpty)

        let parsed = try ByronAddress.fromBase58(base58)
        #expect(parsed == original)
    }

    @Test("init(from: .string) accepts a Base58 address string")
    func testInitFromStringBase58() async throws {
        let original = try ByronAddress.create(
            root: oneRoot,
            attributes: ByronAddressAttributes(derivationPath: Data([0x01, 0x02]))
        )
        let base58  = original.toBase58()
        let parsed  = try ByronAddress(from: .string(base58))

        #expect(parsed == original)
    }

    // MARK: - description

    @Test("description returns Base58 string")
    func testDescription() async throws {
        let addr   = try ByronAddress.create(root: zeroRoot)
        let base58 = addr.toBase58()
        #expect(addr.description == base58)
    }

    // MARK: - Equatable / Hashable

    @Test("equality: same components produce equal addresses")
    func testEqualityMatchingAddresses() async throws {
        let a = try ByronAddress.create(root: zeroRoot)
        let b = try ByronAddress.create(root: zeroRoot)
        #expect(a == b)
    }

    @Test("equality: different roots produce different addresses")
    func testEqualityDifferentRoots() async throws {
        let a = try ByronAddress.create(root: zeroRoot)
        let b = try ByronAddress.create(root: oneRoot)
        #expect(a != b)
    }

    @Test("hashable: equal addresses have the same hash value")
    func testHashable() async throws {
        let a = try ByronAddress.create(root: zeroRoot)
        let b = try ByronAddress.create(root: zeroRoot)
        var setA = Set<ByronAddress>()
        setA.insert(a)
        setA.insert(b)
        #expect(setA.count == 1)
    }

    // MARK: - CRC32 validation

    @Test("parsing fails on a corrupted CRC32")
    func testCRCMismatchIsDetected() async throws {
        let addr  = try ByronAddress.create(root: zeroRoot)
        var bytes = Array(addr.toBytes())
        // Flip the last byte of the payload to corrupt the CRC32 stored inside
        guard !bytes.isEmpty else { return }
        bytes[bytes.count - 1] ^= 0xFF
        #expect(throws: (any Error).self) {
            try ByronAddress(from: .bytes(Data(bytes)))
        }
    }

    // MARK: - CBOR / Codable integration

    @Test("CBORSerializable round-trip (toCBORData / fromCBOR)")
    func testCBORSerializableRoundTrip() async throws {
        let original = try ByronAddress.create(root: oneRoot)
        let cborData = try original.toCBORData()
        let decoded  = try ByronAddress.fromCBOR(data: cborData)
        #expect(decoded == original)
    }

    // MARK: - Real-world address fixture

    /// A known mainnet Byron address used for cross-implementation compatibility checks.
    private let knownBase58 = "37btjrVyb4KDXBNC4haBVPCrro8AQPHwvCMp3RFhhSVWwfFmZ6wwzSK6JK1hY6wHNmtrpTf1kdbva8TCneM2YsiXT7mrzT21EacHnPpz5YyUdj64na"

    @Test("real address: parses from Base58 without throwing")
    func testRealAddressParsesFromBase58() async throws {
        let addr = try ByronAddress(from: .string(knownBase58))
        #expect(addr.root.count == 28)
    }

    @Test("real address: Base58 round-trip produces identical string")
    func testRealAddressBase58RoundTrip() async throws {
        let addr = try ByronAddress(from: .string(knownBase58))
        #expect(addr.toBase58() == knownBase58)
        #expect(addr.description == knownBase58)
    }

    @Test("real address: bytes round-trip produces equal address")
    func testRealAddressBytesRoundTrip() async throws {
        let original = try ByronAddress(from: .string(knownBase58))
        let bytes    = original.toBytes()
        let parsed   = try ByronAddress(from: .bytes(bytes))
        #expect(parsed == original)
        #expect(parsed.toBase58() == knownBase58)
    }

    @Test("real address: network and attributes are decoded correctly")
    func testRealAddressNetworkAndAttributes() async throws {
        let addr = try ByronAddress(from: .string(knownBase58))
        // This address has protocol magic 1097911063, so it is testnet.
        #expect(addr.network == .testnet)
        #expect(addr.attributes.protocolMagic == 1097911063)
        // It also carries an HD derivation path (attribute key 1).
        #expect(addr.attributes.derivationPath != nil)
    }

    @Test("real address: byronType is a valid ByronAddressType")
    func testRealAddressByronTypeIsValid() async throws {
        let addr = try ByronAddress(from: .string(knownBase58))
        #expect(ByronAddressType.allCases.contains(addr.byronType))
    }

    @Test("real address: CBORSerializable round-trip preserves content")
    func testRealAddressCBORRoundTrip() async throws {
        let original = try ByronAddress(from: .string(knownBase58))
        let cborData = try original.toCBORData()
        let decoded  = try ByronAddress.fromCBOR(data: cborData)
        #expect(decoded == original)
        #expect(decoded.toBase58() == knownBase58)
    }

    @Test("real address: CRC32 corruption is detected")
    func testRealAddressCRCCorruptionDetected() async throws {
        let addr  = try ByronAddress(from: .string(knownBase58))
        var bytes = Array(addr.toBytes())
        guard !bytes.isEmpty else { return }
        bytes[bytes.count - 1] ^= 0xFF
        #expect(throws: (any Error).self) {
            try ByronAddress(from: .bytes(Data(bytes)))
        }
    }
}

// MARK: - AddressTests (Byron integration)

struct AddressByronIntegrationTests {

    private let root = Data(repeating: 0x42, count: 28)

    // MARK: - Address.init(from:) handles Byron

    @Test("Address.init(from: .string) handles a Base58 Byron address")
    func testAddressInitFromByronBase58String() async throws {
        let byron   = try ByronAddress.create(root: root)
        let base58  = byron.toBase58()
        let address = try Address(from: .string(base58))

        #expect(address.addressType == .byron)
        #expect(address.byronAddress != nil)
        #expect(address.byronAddress == byron)
        #expect(address.paymentPart == nil)
        #expect(address.stakingPart == nil)
    }

    @Test("Address.init(from: .bytes) handles raw Byron CBOR bytes")
    func testAddressInitFromByronBytes() async throws {
        let byron   = try ByronAddress.create(root: root)
        let bytes   = byron.toBytes()
        let address = try Address(from: .bytes(bytes))

        #expect(address.addressType == .byron)
        #expect(address.byronAddress == byron)
    }

    // MARK: - Address.byronAddress property

    @Test("byronAddress is nil for Shelley addresses")
    func testByronAddressIsNilForShelley() async throws {
        let vkHash  = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(vkHash), network: .mainnet)
        #expect(address.byronAddress == nil)
    }

    @Test("byronAddress is populated for Byron addresses")
    func testByronAddressPopulatedForByron() async throws {
        let byron   = try ByronAddress.create(root: root)
        let address = try Address(from: .bytes(byron.toBytes()))
        #expect(address.byronAddress != nil)
        #expect(address.byronAddress?.root == root)
    }

    // MARK: - Address.toBytes() dispatches correctly

    @Test("toBytes() returns raw CBOR bytes for Byron addresses")
    func testToBytesForByron() async throws {
        let byron   = try ByronAddress.create(root: root)
        let address = try Address(from: .bytes(byron.toBytes()))
        #expect(address.toBytes() == byron.toBytes())
    }

    // MARK: - Address.description

    @Test("description returns Base58 string for Byron addresses")
    func testDescriptionBase58ForByron() async throws {
        let byron   = try ByronAddress.create(root: root)
        let address = try Address(from: .bytes(byron.toBytes()))
        #expect(address.description == byron.toBase58())
    }

    @Test("description returns Bech32 string for Shelley addresses (no regression)")
    func testDescriptionBech32ForShelley() async throws {
        let addr = try Address(from: .string("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"))
        #expect(addr.description == "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
    }

    // MARK: - Address equality

    @Test("two Byron addresses with the same bytes are equal")
    func testByronAddressEquality() async throws {
        let byron    = try ByronAddress.create(root: root)
        let address1 = try Address(from: .bytes(byron.toBytes()))
        let address2 = try Address(from: .bytes(byron.toBytes()))
        #expect(address1 == address2)
    }

    @Test("a Byron address does not equal a Shelley address")
    func testByronNotEqualToShelley() async throws {
        let byron   = try ByronAddress.create(root: root)
        let byronAddr = try Address(from: .bytes(byron.toBytes()))
        let vkHash  = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let shelley = try Address(paymentPart: .verificationKeyHash(vkHash), network: .mainnet)
        #expect(byronAddr != shelley)
    }

    // MARK: - Network propagation

    @Test("Byron testnet address propagates testnet to Address.network")
    func testNetworkPropagation() async throws {
        let attrs   = ByronAddressAttributes(protocolMagic: 1)
        let byron   = try ByronAddress.create(root: root, attributes: attrs)
        let address = try Address(from: .bytes(byron.toBytes()))
        #expect(address.network == .testnet)
    }

    // MARK: - Save / Load round-trip

    @Test("save/load round-trip preserves a Byron address")
    func testSaveLoadRoundTrip() async throws {
        let byron   = try ByronAddress.create(root: root)
        let address = try Address(from: .bytes(byron.toBytes()))

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_byron_\(UUID().uuidString).addr")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try address.save(to: tempURL.path())
        let loaded = try Address.load(from: tempURL.path())

        #expect(address == loaded)
        #expect(loaded.byronAddress != nil)
    }

    // MARK: - Existing Shelley tests still pass (regression guard)

    @Test("Shelley address parsing is unaffected (regression)")
    func testShelleyParsingUnaffected() async throws {
        let addr = try Address(from: .string("addr1qyqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv2t5am"))
        #expect(addr.addressType == .keyKey)
        #expect(addr.byronAddress == nil)
    }

    // MARK: - Real-world address fixture (Address integration)

    private let knownBase58 = "37btjrVyb4KDXBNC4haBVPCrro8AQPHwvCMp3RFhhSVWwfFmZ6wwzSK6JK1hY6wHNmtrpTf1kdbva8TCneM2YsiXT7mrzT21EacHnPpz5YyUdj64na"

    @Test("real address: Address.init(from: .string) recognises it as Byron")
    func testRealAddressStringInit() async throws {
        let address = try Address(from: .string(knownBase58))
        #expect(address.addressType == .byron)
        #expect(address.byronAddress != nil)
        #expect(address.paymentPart == nil)
        #expect(address.stakingPart == nil)
    }

    @Test("real address: Address.init(from: .bytes) recognises it as Byron")
    func testRealAddressBytesInit() async throws {
        let byron   = try ByronAddress(from: .string(knownBase58))
        let address = try Address(from: .bytes(byron.toBytes()))
        #expect(address.addressType == .byron)
        #expect(address.byronAddress == byron)
    }

    @Test("real address: Address.description returns the original Base58 string")
    func testRealAddressDescription() async throws {
        let address = try Address(from: .string(knownBase58))
        #expect(address.description == knownBase58)
    }

    @Test("real address: Address.network is testnet (protocol magic present)")
    func testRealAddressNetworkIsTestnet() async throws {
        let address = try Address(from: .string(knownBase58))
        #expect(address.network == .testnet)
    }

    @Test("real address: Address.toBytes / Address.init(from: .bytes) round-trip")
    func testRealAddressToBytesRoundTrip() async throws {
        let original = try Address(from: .string(knownBase58))
        let bytes    = original.toBytes()
        let parsed   = try Address(from: .bytes(bytes))
        #expect(parsed == original)
        #expect(parsed.description == knownBase58)
    }

    @Test("real address: save/load preserves the Base58 string")
    func testRealAddressSaveLoad() async throws {
        let address = try Address(from: .string(knownBase58))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_real_byron_\(UUID().uuidString).addr")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try address.save(to: tempURL.path())
        let loaded = try Address.load(from: tempURL.path())

        #expect(loaded == address)
        #expect(loaded.description == knownBase58)
        #expect(loaded.byronAddress != nil)
    }
}
