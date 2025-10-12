//
//  Created by Assistant on 11/10/2024
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftCardanoCore

// Test vectors
struct TestVectors {
    static let mnemonic12 = "test walk nut penalty hip pave soap entry language right filter choice"
    static let mnemonic15 = "art forum devote street sure rather head chuckle guard poverty release quote oak craft enemy"
    static let mnemonic24 = "excess behave track soul table wear ocean cash stay nature item turtle palm soccer lunch horror start stumble month panic right must lock dress"
    
    static let mnemonic12Entropy = "df9ed25ed146bf43336a5d7cf7395994"
    static let mnemonic15Entropy = "0ccb74f36b7da1649a8144675522d4d8097c6412"
    static let mnemonic24Entropy = "4e828f9a67ddcff0e6391ad4f26ddb7579f59ba14b6dd4baf63dcfdb9d2420da"
    
    // Expected addresses from pycardano tests
    struct Addresses {
        // 12-word mnemonic addresses
        static let mnemonic12StakeTestnet = "stake_test1uqevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqp8n5xl"
        static let mnemonic12StakeMainnet = "stake1uyevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqxdekzz"
        static let mnemonic12BaseTestnet = "addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp"
        static let mnemonic12BaseMainnet = "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqfjkjv7"
        static let mnemonic12EnterpriseTestnet = "addr_test1vz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerspjrlsz"
        static let mnemonic12EnterpriseMainnet = "addr1vx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzers66hrl8"
        static let mnemonic12PointerTestnet = "addr_test1gz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerspqgpsqe70et"
        static let mnemonic12PointerMainnet = "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5ph3wczvf2w8lunk"
        
        // 15-word mnemonic addresses
        static let mnemonic15BaseTestnet = "addr_test1qpu5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5ewvxwdrt70qlcpeeagscasafhffqsxy36t90ldv06wqrk2qum8x5w"
        static let mnemonic15BaseMainnet = "addr1q9u5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5ewvxwdrt70qlcpeeagscasafhffqsxy36t90ldv06wqrk2qld6xc3"
        static let mnemonic15EnterpriseTestnet = "addr_test1vpu5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5eg57c2qv"
        static let mnemonic15EnterpriseMainnet = "addr1v9u5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5eg0kvk0f"
        static let mnemonic15PointerTestnet = "addr_test1gpu5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5egpqgpsdhdyc0"
        static let mnemonic15PointerMainnet = "addr1g9u5vlrf4xkxv2qpwngf6cjhtw542ayty80v8dyr49rf5evph3wczvf2kd5vam"
        
        // 24-word mnemonic addresses
        static let mnemonic24BaseTestnet = "addr_test1qqy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmn8k8ttq8f3gag0h89aepvx3xf69g0l9pf80tqv7cve0l33sw96paj"
        static let mnemonic24BaseMainnet = "addr1qyy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmn8k8ttq8f3gag0h89aepvx3xf69g0l9pf80tqv7cve0l33sdn8p3d"
        static let mnemonic24EnterpriseTestnet = "addr_test1vqy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmnqtjtf68"
        static let mnemonic24EnterpriseMainnet = "addr1vyy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmnqs6l44z"
        static let mnemonic24PointerTestnet = "addr_test1gqy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmnqpqgps5mee0p"
        static let mnemonic24PointerMainnet = "addr1gyy6nhfyks7wdu3dudslys37v252w2nwhv0fw2nfawemmnyph3wczvf2dqflgt"
    }
    
    struct DerivationPaths {
        static let paymentPath = "m/1852'/1815'/0'/0/0"
        static let stakePath = "m/1852'/1815'/0'/2/0"
        static let accountPath = "m/1852'/1815'/0'"
        static let invalidPath1 = "1852'/1815'/0'/2/0"  // Missing 'm/'
        static let invalidPath2 = "m/1852'/1815'/0'//2/0"  // Double slash
    }
}

// Define address types for testing
enum TestAddressType {
    case enterprise
    case base
    case reward
    case pointer
}

// Test utility functions
func deriveAndCreateAddress(wallet: HDWallet, derivationPath: String, network: Network, addressType: TestAddressType) throws -> String {
    let derivedWallet = try wallet.derive(fromPath: derivationPath)
    let paymentVK = PaymentVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
    
    let address: Address
    switch addressType {
    case .enterprise:
        address = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: nil,
            network: network
        )
    case .base:
        // For base addresses, we need both payment and stake keys
        let stakeWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.stakePath)
        let stakeVK = PaymentVerificationKey(payload: stakeWallet.publicKey, type: nil, description: nil)
        address = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: .verificationKeyHash(stakeVK.hash()),
            network: network
        )
    case .reward:
        address = try Address(
            paymentPart: nil,
            stakingPart: .verificationKeyHash(paymentVK.hash()),
            network: network
        )
    case .pointer:
        address = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: .pointerAddress(PointerAddress(slot: 1, txIndex: 2, certIndex: 3)),
            network: network
        )
    }
    
    return try address.toBech32()
}

// MARK: - Address Generation Tests

@Suite("Address Generation Tests")
struct AddressGenerationTests {
    
    @Test("12-word mnemonic stake addresses")
    func mnemonic12StakeAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.stakePath,
            network: .testnet,
            addressType: .reward
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.stakePath,
            network: .mainnet,
            addressType: .reward
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic12StakeTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic12StakeMainnet)
    }
    
    @Test("12-word mnemonic base addresses")
    func mnemonic12BaseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .base
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .base
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic12BaseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic12BaseMainnet)
    }
    
    @Test("12-word mnemonic enterprise addresses")
    func mnemonic12EnterpriseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .enterprise
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .enterprise
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic12EnterpriseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic12EnterpriseMainnet)
    }
    
    @Test("12-word mnemonic pointer addresses")
    func mnemonic12PointerAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .pointer
        )
        
        // Test pointer with different values for mainnet
        let derivedWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.paymentPath)
        let paymentVK = PaymentVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
        let mainnetAddress = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: .pointerAddress(PointerAddress(slot: 24157, txIndex: 177, certIndex: 42)),
            network: .mainnet
        ).toBech32()
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic12PointerTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic12PointerMainnet)
    }
    
    @Test("15-word mnemonic base addresses")
    func mnemonic15BaseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic15)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .base
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .base
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic15BaseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic15BaseMainnet)
    }
    
    @Test("15-word mnemonic enterprise addresses")
    func mnemonic15EnterpriseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic15)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .enterprise
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .enterprise
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic15EnterpriseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic15EnterpriseMainnet)
    }
    
    @Test("15-word mnemonic pointer addresses")
    func mnemonic15PointerAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic15)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .pointer
        )
        
        // Test pointer with different values for mainnet
        let derivedWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.paymentPath)
        let paymentVK = PaymentVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
        let mainnetAddress = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: .pointerAddress(PointerAddress(slot: 24157, txIndex: 177, certIndex: 42)),
            network: .mainnet
        ).toBech32()
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic15PointerTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic15PointerMainnet)
    }
    
    @Test("24-word mnemonic base addresses")
    func mnemonic24BaseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .base
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .base
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic24BaseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic24BaseMainnet)
    }
    
    @Test("24-word mnemonic enterprise addresses")
    func mnemonic24EnterpriseAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .enterprise
        )
        
        let mainnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .mainnet,
            addressType: .enterprise
        )
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic24EnterpriseTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic24EnterpriseMainnet)
    }
    
    @Test("24-word mnemonic pointer addresses")
    func mnemonic24PointerAddresses() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        
        let testnetAddress = try deriveAndCreateAddress(
            wallet: wallet,
            derivationPath: TestVectors.DerivationPaths.paymentPath,
            network: .testnet,
            addressType: .pointer
        )
        
        // Test pointer with different values for mainnet
        let derivedWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.paymentPath)
        let paymentVK = PaymentVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
        let mainnetAddress = try Address(
            paymentPart: .verificationKeyHash(paymentVK.hash()),
            stakingPart: .pointerAddress(PointerAddress(slot: 24157, txIndex: 177, certIndex: 42)),
            network: .mainnet
        ).toBech32()
        
        #expect(testnetAddress == TestVectors.Addresses.mnemonic24PointerTestnet)
        #expect(mainnetAddress == TestVectors.Addresses.mnemonic24PointerMainnet)
    }
}

// MARK: - Derivation Path Tests

@Suite("Derivation Path Tests")
struct DerivationPathTests {
    
    @Test("Full private derivation chain")
    func fullPrivateDerivation() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        // Derive step by step with private keys - the derive method adds (1 << 31) for hardened keys
        let step1 = try wallet.derive(index: 1852, isPrivate: true, hardened: true)
        let step2 = try step1.derive(index: 1815, isPrivate: true, hardened: true)
        let step3 = try step2.derive(index: 0, isPrivate: true, hardened: true)
        let step4 = try step3.derive(index: 2, isPrivate: true, hardened: false)
        let step5 = try step4.derive(index: 0, isPrivate: true, hardened: false)
        
        // Compare with direct path derivation
        let directDerivation = try wallet.derive(fromPath: TestVectors.DerivationPaths.stakePath)
        
        #expect(step5.publicKey == directDerivation.publicKey)
        #expect(step5.chainCode == directDerivation.chainCode)
    }
    
    @Test("Mixed public and private derivation")
    func mixedPublicPrivateDerivation() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        // Derive to account level privately
        let accountWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.accountPath)
        
        // Then derive publicly
        let publicStep1 = try accountWallet.derive(index: 2, isPrivate: false, hardened: false)
        let publicStep2 = try publicStep1.derive(index: 0, isPrivate: false, hardened: false)
        
        // Compare with full private derivation
        let fullPrivate = try wallet.derive(fromPath: TestVectors.DerivationPaths.stakePath)
        
        #expect(publicStep2.publicKey == fullPrivate.publicKey)
        #expect(publicStep2.chainCode == fullPrivate.chainCode)
    }
    
    @Test("Invalid derivation paths")
    func invalidDerivationPaths() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        // Test path without "m/" prefix
        #expect(throws: BIP32Error.self) {
            _ = try wallet.derive(fromPath: TestVectors.DerivationPaths.invalidPath1)
        }
    }
    
    @Test("Incorrect index type in derivation")
    func incorrectIndexType() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        // This should work fine since we're using Int, but let's test edge cases
        #expect(throws: Never.self) {
            _ = try wallet.derive(index: 1815, isPrivate: true, hardened: true)
        }
        
        // Test derivation with hardened key using public derivation (should fail)
        let accountWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.accountPath)
        #expect(throws: CardanoCoreError.self) {
            _ = try accountWallet.derive(index: 1815, isPrivate: false, hardened: true)
        }
    }
}

// MARK: - Entropy Wallet Tests

@Suite("Entropy Wallet Tests")
struct EntropyWalletTests {
    
    @Test("Create wallet from entropy")
    func createFromEntropy() async throws {
        let wallet12 = try HDWallet.fromEntropy(entropy: TestVectors.mnemonic12Entropy)
        let wallet15 = try HDWallet.fromEntropy(entropy: TestVectors.mnemonic15Entropy)
        let wallet24 = try HDWallet.fromEntropy(entropy: TestVectors.mnemonic24Entropy)
        
        // Test that derived addresses match those from mnemonic
        let address12 = try deriveAndCreateAddress(
            wallet: wallet12,
            derivationPath: TestVectors.DerivationPaths.stakePath,
            network: .testnet,
            addressType: .reward
        )
        
        #expect(address12 == TestVectors.Addresses.mnemonic12StakeTestnet)
        
        // Verify entropy properties
        #expect(wallet12.entropy == TestVectors.mnemonic12Entropy)
        #expect(wallet15.entropy == TestVectors.mnemonic15Entropy)
        #expect(wallet24.entropy == TestVectors.mnemonic24Entropy)
    }
    
    @Test("Invalid entropy input")
    func invalidEntropyInput() async throws {
        // Test invalid characters
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.fromEntropy(entropy: "*(#_")
        }
        
        // Test wrong length
        let wrongLengthEntropy = "df9ed25ed146bf43336a5d7cf73959"
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.fromEntropy(entropy: wrongLengthEntropy)
        }
    }
    
    @Test("Entropy validation")
    func entropyValidation() async throws {
        // Valid entropies
        #expect(HDWallet.isEntropy(entropy: TestVectors.mnemonic12Entropy) == true)
        #expect(HDWallet.isEntropy(entropy: TestVectors.mnemonic15Entropy) == true)
        #expect(HDWallet.isEntropy(entropy: TestVectors.mnemonic24Entropy) == true)
        
        // Invalid entropies
        let wrongLengthEntropy = "df9ed25ed146bf43336a5d7cf73959"
        #expect(HDWallet.isEntropy(entropy: wrongLengthEntropy) == false)
        
        let invalidCharacters = "*(#_"
        #expect(HDWallet.isEntropy(entropy: invalidCharacters) == false)
    }
}

// MARK: - Extended Key Tests

@Suite("Extended Key Tests")
struct ExtendedKeyTests {
    
    @Test("Extended payment signing key creation")
    func extendedPaymentSigningKeyCreation() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        let derivedWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.paymentPath)
        
        let extendedSigningKey = try PaymentExtendedSigningKey.fromHDWallet(derivedWallet)
        let extendedVerificationKey: PaymentExtendedVerificationKey = try extendedSigningKey.toVerificationKey()
        
        // Test that the keys are consistent
        let paymentVK = PaymentVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
        
        let (extendedHash, _): (VerificationKeyHash, PaymentVerificationKey) = try extendedVerificationKey.hash()
        let paymentHash = try paymentVK.hash()
        #expect(extendedHash == paymentHash)
    }
    
    @Test("Extended stake signing key creation")
    func extendedStakeSigningKeyCreation() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        let derivedWallet = try wallet.derive(
            fromPath: TestVectors.DerivationPaths.stakePath
        )
        
        let extendedSigningKey = try StakeExtendedSigningKey.fromHDWallet(derivedWallet)
        let extendedVerificationKey: StakeExtendedVerificationKey = try extendedSigningKey.toVerificationKey()
        
        // Test that the keys are consistent
        let stakeVK = StakeVerificationKey(payload: derivedWallet.publicKey, type: nil, description: nil)
        
        let (extendedHash, _): (VerificationKeyHash, StakeVerificationKey) = try extendedVerificationKey.hash()
        let stakeHash = try stakeVK.hash()
        #expect(extendedHash == stakeHash)
    }
    
    @Test("Extended key round trip")
    func extendedKeyRoundTrip() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        let spendWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.paymentPath)
        let stakeWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.stakePath)
        
        let spendExtendedSK = try PaymentExtendedSigningKey.fromHDWallet(spendWallet)
        let spendExtendedVK: PaymentExtendedVerificationKey = try spendExtendedSK.toVerificationKey()
        
        let stakeExtendedSK = try PaymentExtendedSigningKey.fromHDWallet(stakeWallet)
        let stakeExtendedVK: PaymentExtendedVerificationKey = try stakeExtendedSK.toVerificationKey()
        
        // Test address generation matches previous tests
        let (spendHash, _): (VerificationKeyHash, PaymentVerificationKey) = try spendExtendedVK.hash()
        let (stakeHash, _): (VerificationKeyHash, PaymentVerificationKey) = try stakeExtendedVK.hash()
        
        let address = try Address(
            paymentPart: .verificationKeyHash(spendHash),
            stakingPart: .verificationKeyHash(stakeHash),
            network: .testnet
        ).toBech32()
        
        #expect(address == TestVectors.Addresses.mnemonic24BaseTestnet)
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling Tests")  
struct ErrorHandlingTests {
    
    @Test("Unsupported mnemonic strength")
    func unsupportedMnemonicStrength() async throws {
        // Test with unsupported word count (this would need to be implemented in generateMnemonic)
        // For now, test existing functionality
        let validMnemonic = try HDWallet.generateMnemonic(wordCount: .twelve)
        #expect(validMnemonic.count == 12)
        
        let validMnemonic24 = try HDWallet.generateMnemonic(wordCount: .twentyFour)
        #expect(validMnemonic24.count == 24)
    }
    
    @Test("Unsupported language generation")
    func unsupportedLanguageGeneration() async throws {
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.generateMnemonic(language: .unsupported)
        }
    }
    
    @Test("Invalid mnemonic words")
    func invalidMnemonicWords() async throws {
        let wrongMnemonic = "test walk nut penalty hip pave soap entry language right filter"
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.fromMnemonic(mnemonic: wrongMnemonic)
        }
        
        #expect(try HDWallet.isMnemonic(mnemonic: wrongMnemonic) == false)
    }
    
    @Test("Path derivation errors")
    func pathDerivationErrors() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        
        // Test various invalid paths
        let invalidPaths = [
            "1852'/1815'/0'/2/0",    // Missing m/
            "m/",                    // Empty after m/
            "m/1852//1815'/0'/2/0",  // Double slash
            "m/1852'/1815'/0'/2/",   // Trailing slash
        ]
        
        for invalidPath in invalidPaths {
            #expect(throws: BIP32Error.self) {
                _ = try wallet.derive(fromPath: invalidPath)
            }
        }
    }
    
    @Test("Hardened derivation with public key")
    func hardenedDerivationWithPublicKey() async throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic12)
        let accountWallet = try wallet.derive(fromPath: TestVectors.DerivationPaths.accountPath)
        
        // Try to derive hardened path with public key (should fail)
        #expect(throws: CardanoCoreError.self) {
            _ = try accountWallet.derive(index: 1815, isPrivate: false, hardened: true)
        }
    }
}
