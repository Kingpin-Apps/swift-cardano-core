import Foundation
import Testing
import SwiftCardanoCore

/// The code examples of the Addresses guide (`Addresses.md`), compiled and run
/// so that the guide stays true to the API. Each test holds one example as the
/// guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Addresses guide examples")
struct AddressesGuideExamplesTests {
    /// Stand-ins for values the guide assumes the reader already has.
    let paymentKeyPair = try! PaymentKeyPair.generate()
    let stakeKeyPair = try! StakeKeyPair.generate()
    let nativeScript = NativeScript.invalidBefore(BeforeScript(slot: 1000))

    @Test(.disabled("Writes address files to the working directory"))
    func baseAddresses() throws {
        // Generate key pairs
        let paymentKeyPair = try PaymentKeyPair.generate()
        let stakeKeyPair = try StakeKeyPair.generate()

        // Create base address
        let baseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .testnet
        )

        print("Base Address: \(try baseAddress.toBech32())")

        // Save to file (Cardano CLI compatible)
        try baseAddress.save(to: "base.addr")
    }

    @Test func enterpriseAddresses() throws {
        // Enterprise address for exchanges or simple payments
        let enterpriseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            network: .mainnet
        )

        print("Enterprise Address: \(try enterpriseAddress.toBech32())")
    }

    @Test func rewardAddresses() throws {
        // Reward address for stake pool rewards
        let rewardAddress = try Address(
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .mainnet
        )

        print("Reward Address: \(try rewardAddress.toBech32())")
    }

    @Test func scriptAddresses() throws {
        // Address controlled by a script
        let scriptHash = try nativeScript.scriptHash()
        let scriptAddress = try Address(
            paymentPart: .scriptHash(scriptHash),
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .testnet
        )

        print("Script Address: \(try scriptAddress.toBech32())")
    }

    @Test func parseFromBech32String() throws {
        // Parse various address formats
        let testnetAddr = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let mainnetAddr = "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqfjkjv7"
        let rewardAddr = "stake1uyevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqxdekzz"

        do {
            let parsedTestnet = try Address.fromBech32(testnetAddr)
            let parsedMainnet = try Address.fromBech32(mainnetAddr)
            let parsedReward = try Address.fromBech32(rewardAddr)

            print("Parsed testnet address: \(parsedTestnet.network)")
            print("Parsed mainnet address: \(parsedMainnet.network)")
            print("Parsed reward address: \(parsedReward.network)")

        } catch {
            print("Address parsing failed: \(error)")
            Issue.record(error)
        }
    }

    @Test(.disabled("Writes address files to the working directory"))
    func builtInSaveAndLoad() throws {
        // Create an address
        let paymentKeyPair = try PaymentKeyPair.generate()
        let stakeKeyPair = try StakeKeyPair.generate()

        let baseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .testnet
        )

        // Save address to file
        try baseAddress.save(to: "payment.addr")
        print("Address saved to payment.addr")

        // Load address from file
        let loadedAddress = try Address.load(from: "payment.addr")
        print("Loaded address: \(try loadedAddress.toBech32())")

        // Verify they match
        #expect(baseAddress == loadedAddress)
    }

    @Test(.disabled("Writes address files to the working directory"))
    func fileFormatCompatibility() throws {
        let baseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .mainnet)

        // Save different address types
        let enterpriseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            network: .mainnet
        )

        let rewardAddress = try Address(
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .mainnet
        )

        // Save to files
        try baseAddress.save(to: "base.addr")
        try enterpriseAddress.save(to: "enterprise.addr")
        try rewardAddress.save(to: "stake.addr")

        // These files can be used directly with cardano-cli commands
        // For example: cardano-cli transaction build ... --tx-out $(cat base.addr)+1000000
    }

    @Test func errorHandling() throws {
        do {
            let address = try Address.fromBech32("invalid_address_string")
            guard address.network == .mainnet else {
                print("Not a mainnet address")
                return
            }
            print("Mainnet address: \(try address.toBech32())")
        } catch CardanoCoreError.decodingError(let message) {
            print("Not an address: \(message ?? "")")
        } catch CardanoCoreError.invalidAddressInputError(let message) {
            print("Invalid address: \(message ?? "")")
        } catch CardanoCoreError.encodingError(let message) {
            print("Address encoding failed: \(message ?? "")")
        } catch {
            print("Address parsing failed: \(error)")
        }

        // The string is not an address, so the first case catches it.
        let error = #expect(throws: CardanoCoreError.self) {
            try Address.fromBech32("invalid_address_string")
        }
        guard case .decodingError = error else {
            Issue.record("Expected decodingError, got \(String(describing: error))")
            return
        }
        // Bytes whose header names no network throw invalidAddressInputError.
        let headerError = #expect(throws: CardanoCoreError.self) {
            try Address.fromCBOR(data: Data([0x41, 0xff]))
        }
        guard case .invalidAddressInputError = headerError else {
            Issue.record("Expected invalidAddressInputError, got \(String(describing: headerError))")
            return
        }
    }

    @Test(.disabled("Writes address files to the working directory"))
    func errorHandlingWithFileOperations() throws {
        let baseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            network: .testnet)

        // Handle file operation errors
        do {
            // Save address
            try baseAddress.save(to: "my-address.addr")

            // Load address
            let address = try Address.load(from: "my-address.addr")
            print("Successfully loaded address: \(try address.toBech32())")

        } catch CardanoCoreError.ioError(let message) {
            print("File operation failed: \(message ?? "")")
        } catch CardanoCoreError.decodingError(let message) {
            print("Address parsing failed: \(message ?? "")")
        } catch {
            print("Unexpected error: \(error)")
        }
    }

    /// The file example's cases are the ones `save(to:)` and `load(from:)`
    /// throw; run here in a temporary directory.
    @Test func errorHandlingWithFileOperationsCatchesEachCase() throws {
        let directory = NSTemporaryDirectory() + "addresses-guide-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let baseAddress = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            network: .testnet)

        // Saving over an existing file
        try baseAddress.save(to: directory + "my-address.addr")
        #expect(throws: CardanoCoreError.ioError("File already exists: \(directory)my-address.addr")) {
            try baseAddress.save(to: directory + "my-address.addr")
        }
        // Loading a missing file
        #expect(throws: CardanoCoreError.ioError("File not found: \(directory)missing.addr")) {
            try Address.load(from: directory + "missing.addr")
        }
        // Loading a file that holds no address
        try "not an address".write(toFile: directory + "junk.addr", atomically: true, encoding: .utf8)
        let error = #expect(throws: CardanoCoreError.self) {
            try Address.load(from: directory + "junk.addr")
        }
        guard case .decodingError = error else {
            Issue.record("Expected decodingError, got \(String(describing: error))")
            return
        }
    }

    @Test func testingAndValidation() throws {
        // Address round-trip testing
        func testAddressRoundTrip() throws {
            let paymentKeyPair = try PaymentKeyPair.generate()
            let stakeKeyPair = try StakeKeyPair.generate()

            let originalAddress = try Address(
                paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
                stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
                network: .testnet
            )

            // Test Bech32 round-trip
            let bech32String = try originalAddress.toBech32()
            let parsedAddress = try Address.fromBech32(bech32String)
            #expect(originalAddress == parsedAddress)

            // Test CBOR round-trip
            let cborData = try originalAddress.toCBORData()
            let deserializedAddress = try Address.fromCBOR(data: cborData)
            #expect(originalAddress == deserializedAddress)
        }

        // Address format validation
        func validateAddressFormat(_ addressString: String) -> Bool {
            do {
                _ = try Address.fromBech32(addressString)
                return true
            } catch {
                return false
            }
        }

        // Test known address formats
        let validAddresses = [
            "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
            "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqfjkjv7",
            "stake1uyevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqxdekzz"
        ]

        for addressString in validAddresses {
            #expect(validateAddressFormat(addressString))
        }

        try testAddressRoundTrip()
    }
}
