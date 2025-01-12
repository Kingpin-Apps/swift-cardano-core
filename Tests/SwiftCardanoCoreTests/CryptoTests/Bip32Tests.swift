//
//  Created by Hareem Adderley on 19/06/2024 AT 8:13 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//
import XCTest
import SwiftMnemonic

@testable import SwiftCardanoCore

final class HDWalletTests: XCTestCase {

    let mnemonic12 = "test walk nut penalty hip pave soap entry language right filter choice"
    let mnemonic15 = "art forum devote street sure rather head chuckle guard poverty release quote oak craft enemy"
    let mnemonic24 = "excess behave track soul table wear ocean cash stay nature item turtle palm soccer lunch horror start stumble month panic right must lock dress"

    let mnemonic12Entropy = "df9ed25ed146bf43336a5d7cf7395994"
    let mnemonic15Entropy = "0ccb74f36b7da1649a8144675522d4d8097c6412"
    let mnemonic24Entropy = "4e828f9a67ddcff0e6391ad4f26ddb7579f59ba14b6dd4baf63dcfdb9d2420da"

    func testIsMnemonic() throws {
        XCTAssertTrue(try HDWallet.isMnemonic(mnemonic: mnemonic12))
        XCTAssertTrue(try HDWallet.isMnemonic(mnemonic: mnemonic15))
        XCTAssertTrue(try HDWallet.isMnemonic(mnemonic: mnemonic24))
    }

    func testIsMnemonicLanguageExplicitlySpecified() throws {
        XCTAssertTrue(try HDWallet.isMnemonic(mnemonic: mnemonic12, language: .english))
    }

    func testIsMnemonicIncorrectMnemonic() throws {
        let wrongMnemonic = "test walk nut penalty hip pave soap entry language right filter"
        XCTAssertFalse(try HDWallet.isMnemonic(mnemonic: wrongMnemonic))
    }

    func testIsMnemonicUnsupportedLanguage() throws {
        XCTAssertThrowsError(try HDWallet.isMnemonic(mnemonic: mnemonic12, language: .unsupported)) { error in
            guard error is CardanoCoreError else {
                XCTFail("Expected MnemonicError but got \(error)")
                return
            }
        }
    }

    func testMnemonicGeneration() throws {
        let mnemonicWords = try HDWallet.generateMnemonic(wordCount: .twelve)
        XCTAssertTrue(try HDWallet.isMnemonic(mnemonic: mnemonicWords.joined(separator: " ")))
    }

    func testGenerateMnemonicUnsupportedLang() throws {
        XCTAssertThrowsError(try HDWallet.generateMnemonic(language: .unsupported)) { error in
            guard error is CardanoCoreError else {
                XCTFail("Expected MnemonicError but got \(error)")
                return
            }
        }
    }

    func testFromMnemonicInvalidMnemonic() throws {
        let wrongMnemonic = "test walk nut penalty hip pave soap entry language right filter"
        XCTAssertThrowsError(try HDWallet.fromMnemonic(mnemonic: wrongMnemonic)) { error in
            guard let error = error as? CardanoCoreError else {
                XCTFail("Expected MnemonicError but got \(error)")
                return
            }
            XCTAssertEqual(error, .invalidDataError("Invalid mnemonic words."))
        }
    }

    func testDeriveFromPathIncorrectPath() throws {
        let rootMissingPath = "1852'/1815'/0'/2/0"
        XCTAssertThrowsError(try HDWallet.fromMnemonic(mnemonic: mnemonic12).derive(fromPath: rootMissingPath)) { error in
            guard let error = error as? BIP32Error else {
                XCTFail("Expected BIP32Error but got \(error)")
                return
            }
            XCTAssertEqual(error, .invalidPath("Bad path, please insert like this type of path \"m/0\'/0\"!"))
        }
    }

    func testIsEntropy() {
        XCTAssertTrue(HDWallet.isEntropy(entropy: mnemonic12Entropy))
    }

    func testIsEntropyWrongInput() {
        let wrongEntropy = "df9ed25ed146bf43336a5d7cf73959"
        XCTAssertFalse(HDWallet.isEntropy(entropy: wrongEntropy))
    }

    func testIsEntropyValueError() {
        XCTAssertFalse(HDWallet.isEntropy(entropy: "*(#_"))
    }
}
