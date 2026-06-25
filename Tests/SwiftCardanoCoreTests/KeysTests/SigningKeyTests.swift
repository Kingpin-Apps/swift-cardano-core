import Foundation
import Testing

@testable import SwiftCardanoCore

@Suite  struct SigningKeyTests {
    @Test
    func testSigningKeyGenerate() throws {
        let signingKey = try SigningKey.generate()
        #expect(
            signingKey.payload.count > 0,
            "Generated signing key payload should not be empty"
        )
    }
    
    @Test
    func testSigningData() throws {
        let signingKey = try SigningKey.generate()
        let message = "Test message".data(using: .utf8)!
        
        let signature = try signingKey.sign(data: message)
        #expect(signature.count > 0, "Signature should not be empty")
    }
    
    @Test
    func testToVerificationKey() throws {
        let signingKey = try SigningKey.generate()
        let verificationKey: VerificationKey = try signingKey.toVerificationKey()
        
        #expect(verificationKey.payload.count > 0, "Verification key payload should not be empty")
    }
    
    @Test
    func testSigningConsistency() throws {
        let signingKey = try SigningKey.generate()
        let message = "Consistency check".data(using: .utf8)!

        let signature1 = try signingKey.sign(data: message)
        let signature2 = try signingKey.sign(data: message)

        #expect(signature1 == signature2, "Signatures for the same message must be identical")
    }

    /// A `SigningKeyType` built from an extended (BIP32) key must yield a
    /// *non-extended* 32-byte verification key from `toVerificationKeyType()`.
    /// The extended (64-byte) form embeds the chain code and is rejected by the
    /// ledger in a tx witness ("decodeVerKeyDSIGN: wrong length, expected 32
    /// bytes but got 64").
    @Test
    func testExtendedSigningKeyTypeYieldsNonExtendedVerificationKey() throws {
        let wallet = try HDWallet.fromMnemonic(mnemonic: TestVectors.mnemonic24)
        let extendedSigningKey = try PaymentExtendedSigningKey.fromHDWallet(wallet)
        let keyType = SigningKeyType.extendedSigningKey(extendedSigningKey)

        let vkeyType = try keyType.toVerificationKeyType()

        guard case .verificationKey(let vkey) = vkeyType else {
            Issue.record("Expected a non-extended .verificationKey, got \(vkeyType)")
            return
        }
        #expect(
            vkey.payload.count == 32,
            "Witness verification key must be the non-extended 32-byte Ed25519 key"
        )
    }
}
