//
//  Created by Hareem Adderley on 19/06/2024 AT 8:13 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//
import Foundation
import Testing
import SwiftMnemonic

@testable import SwiftCardanoCore

@Suite("HDWallet Tests")
struct HDWalletTests {

    // Test fixtures
    static let mnemonic12 = "test walk nut penalty hip pave soap entry language right filter choice"
    static let mnemonic15 = "art forum devote street sure rather head chuckle guard poverty release quote oak craft enemy"
    static let mnemonic24 = "excess behave track soul table wear ocean cash stay nature item turtle palm soccer lunch horror start stumble month panic right must lock dress"

    static let mnemonic12Entropy = "df9ed25ed146bf43336a5d7cf7395994"
    static let mnemonic15Entropy = "0ccb74f36b7da1649a8144675522d4d8097c6412"
    static let mnemonic24Entropy = "4e828f9a67ddcff0e6391ad4f26ddb7579f59ba14b6dd4baf63dcfdb9d2420da"

    @Test("Valid mnemonics are recognized")
    func isMnemonic_valid() async throws {
        #expect(try HDWallet.isMnemonic(mnemonic: Self.mnemonic12))
        #expect(try HDWallet.isMnemonic(mnemonic: Self.mnemonic15))
        #expect(try HDWallet.isMnemonic(mnemonic: Self.mnemonic24))
    }

    @Test("fromSeed(seedData:) matches fromSeed(seed: hex) for the same bytes")
    func fromSeed_dataAndHexMatch() async throws {
        // 96-byte synthetic seed — exercises the Data-accepting overload
        // added to keep secret material out of the Swift string allocator.
        var bytes = [UInt8]()
        for i in 0..<96 {
            bytes.append(UInt8(i & 0xFF))
        }
        let seedData = Data(bytes)
        let seedHex = seedData.hexEncodedString()

        let viaData = try HDWallet.fromSeed(seedData: seedData)
        let viaHex = try HDWallet.fromSeed(seed: seedHex)

        #expect(viaData.rootXPrivateKey == viaHex.rootXPrivateKey)
        #expect(viaData.rootPublicKey == viaHex.rootPublicKey)
        #expect(viaData.rootChainCode == viaHex.rootChainCode)
        #expect(viaData.xPrivateKey == viaHex.xPrivateKey)
        #expect(viaData.publicKey == viaHex.publicKey)
        #expect(viaData.chainCode == viaHex.chainCode)
        #expect(viaData.path == viaHex.path)
    }

    @Test("Valid mnemonic with explicit language")
    func isMnemonic_languageExplicit() async throws {
        #expect(try HDWallet.isMnemonic(mnemonic: Self.mnemonic12, language: .english))
    }

    @Test("Invalid mnemonic is rejected")
    func isMnemonic_invalid() async throws {
        let wrongMnemonic = "test walk nut penalty hip pave soap entry language right filter"
        #expect(try HDWallet.isMnemonic(mnemonic: wrongMnemonic) == false)
    }

    @Test("Unsupported language throws CardanoCoreError")
    func isMnemonic_unsupportedLanguage() async throws {
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.isMnemonic(mnemonic: Self.mnemonic12, language: .unsupported)
        }
    }

    @Test("Generated 12-word mnemonic is valid")
    func mnemonicGeneration_isValid() async throws {
        let mnemonicWords = try HDWallet.generateMnemonic(wordCount: .twelve)
        #expect(try HDWallet.isMnemonic(mnemonic: mnemonicWords.joined(separator: " ")))
    }

    @Test("Generating mnemonic with unsupported language throws CardanoCoreError")
    func generateMnemonic_unsupportedLanguage() async throws {
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.generateMnemonic(language: .unsupported)
        }
    }

    @Test("fromMnemonic with invalid mnemonic throws specific CardanoCoreError")
    func fromMnemonic_invalidMnemonic() async throws {
        let wrongMnemonic = "test walk nut penalty hip pave soap entry language right filter"
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.fromMnemonic(mnemonic: wrongMnemonic)
        }
    }

    @Test("Deriving from incorrect path throws BIP32Error.invalidPath")
    func deriveFromPath_incorrectPath() async throws {
        let rootMissingPath = "1852'/1815'/0'/2/0"
        let wallet = try HDWallet.fromMnemonic(mnemonic: Self.mnemonic12)
        #expect(throws: BIP32Error.self) {
            _ = try wallet.derive(fromPath: rootMissingPath)
        }
    }

    @Test("Valid entropy is recognized")
    func isEntropy_valid() async throws {
        #expect(HDWallet.isEntropy(entropy: Self.mnemonic12Entropy))
    }

    @Test("Invalid entropy length is rejected")
    func isEntropy_wrongLength() async throws {
        let wrongEntropy = "df9ed25ed146bf43336a5d7cf73959"
        #expect(HDWallet.isEntropy(entropy: wrongEntropy) == false)
    }

    @Test("Invalid entropy characters are rejected")
    func isEntropy_invalidCharacters() async throws {
        #expect(HDWallet.isEntropy(entropy: "*(#_") == false)
    }

    // MARK: - Multi-language mnemonic support

    /// Round-trip a freshly-generated phrase in each BIP-39 language back through
    /// `HDWallet.fromMnemonic`. Pre-fix the function hard-coded an English-only
    /// validation step, so non-English phrases threw `invalidDataError` even though
    /// the downstream `Mnemonic(from:)` constructor handled them fine.
    @Test("fromMnemonic accepts phrases in every supported language")
    func fromMnemonic_allSupportedLanguages() async throws {
        for language in SUPPORTED_MNEMONIC_LANGS {
            let words = try HDWallet.generateMnemonic(language: language, wordCount: .twelve)
            // Generators in non-English locales return ASCII-space-joined arrays; the
            // upstream Mnemonic API also tolerates U+3000 (handled in the Japanese test
            // below). Either separator round-trips through NFKD normalization.
            let phrase = words.joined(separator: " ")
            let wallet = try HDWallet.fromMnemonic(mnemonic: phrase)
            #expect(!wallet.xPrivateKey.isEmpty, "Empty xPrivateKey for language \(language)")
            #expect(!wallet.publicKey.isEmpty, "Empty publicKey for language \(language)")
        }
    }

    /// Japanese BIP-39 phrases use `U+3000 IDEOGRAPHIC SPACE` as their canonical word
    /// separator. NFKD has a compatibility mapping `U+3000 → U+0020`, so the existing
    /// `decomposedStringWithCompatibilityMapping` call in `fromMnemonic` covers the
    /// separator-conversion without a language-specific code path.
    @Test("fromMnemonic handles Japanese ideographic-space separator")
    func fromMnemonic_japaneseIdeographicSpace() async throws {
        let words = try HDWallet.generateMnemonic(language: .japanese, wordCount: .twelve)
        let asciiJoined = words.joined(separator: " ")
        let ideographicJoined = words.joined(separator: "\u{3000}")

        let walletAscii = try HDWallet.fromMnemonic(mnemonic: asciiJoined)
        let walletIdeographic = try HDWallet.fromMnemonic(mnemonic: ideographicJoined)

        // Both separators decompose to ASCII space under NFKD, so the derived keys
        // must be byte-identical.
        #expect(walletAscii.xPrivateKey == walletIdeographic.xPrivateKey)
        #expect(walletAscii.publicKey == walletIdeographic.publicKey)
        #expect(walletAscii.chainCode == walletIdeographic.chainCode)
    }

    /// The wallet derived from a non-English phrase must match the wallet built from
    /// the equivalent raw entropy — proves the language path doesn't perturb the seed
    /// derivation, just the wordlist used to recover entropy.
    @Test("fromMnemonic non-English wallet matches fromEntropy")
    func fromMnemonic_nonEnglishMatchesFromEntropy() async throws {
        // Pick Spanish — different wordlist, same ASCII-space separator, so we isolate
        // the wordlist-detection change from the separator-handling one.
        let words = try HDWallet.generateMnemonic(language: .spanish, wordCount: .twelve)
        let phrase = words.joined(separator: " ")
        let walletFromPhrase = try HDWallet.fromMnemonic(mnemonic: phrase)
        let walletFromEntropy = try HDWallet.fromEntropy(entropy: walletFromPhrase.entropy ?? "")
        #expect(walletFromPhrase.xPrivateKey == walletFromEntropy.xPrivateKey)
        #expect(walletFromPhrase.publicKey == walletFromEntropy.publicKey)
        #expect(walletFromPhrase.chainCode == walletFromEntropy.chainCode)
    }
}
