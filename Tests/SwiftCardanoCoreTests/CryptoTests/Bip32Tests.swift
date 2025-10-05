//
//  Created by Hareem Adderley on 19/06/2024 AT 8:13 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//
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
}
