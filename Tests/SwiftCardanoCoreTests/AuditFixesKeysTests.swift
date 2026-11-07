import Testing
import Foundation

import CBORCodable
@testable import SwiftCardanoCore

/// A text envelope whose `cborHex` is `payload` as a CBOR byte string.
private func envelope(type: String, payload: Data) throws -> String {
    let cborHex = try CBOREncoder().encode(payload).toHex
    return """
    {"type": "\(type)", "description": "x", "cborHex": "\(cborHex)"}
    """
}

/// A fresh path in the temporary directory.
private func temporaryKeyPath(_ suffix: String) -> String {
    NSTemporaryDirectory() + "audit-keys-\(UUID().uuidString).\(suffix)"
}

@Suite struct ExtendedSigningKeyLengthTests {
    @Test("Extended signing keys reject every payload that is not 128 bytes",
          arguments: [0, 32, 64, 80, 95, 96, 127, 129])
    func initializersRejectWrongLengths(count: Int) {
        let payload = Data(repeating: 0x11, count: count)
        #expect(throws: CardanoCoreError.self) { try ExtendedSigningKey(payload: payload) }
        #expect(throws: CardanoCoreError.self) { try PaymentExtendedSigningKey(payload: payload) }
        #expect(throws: CardanoCoreError.self) { try StakeExtendedSigningKey(payload: payload) }
    }

    @Test("A short extended key envelope throws instead of trapping in sign",
          arguments: [32, 80])
    func shortEnvelopeThrows(count: Int) throws {
        let json = try envelope(
            type: PaymentExtendedSigningKey.TYPE,
            payload: Data(repeating: 0x11, count: count))
        #expect(throws: CardanoCoreError.self) {
            let key = try PaymentExtendedSigningKey.fromTextEnvelope(json, validateType: true)
            _ = try key.sign(data: Data("message".utf8))
        }
    }

    @Test("sign and toVerificationKey check the payload length before slicing it",
          arguments: [0, 32, 63, 64, 80, 95])
    func signAndDeriveCheckLength(count: Int) throws {
        var key = try PaymentExtendedSigningKey.generate()
        key._payload = Data(repeating: 0x11, count: count)
        #expect(throws: CardanoCoreError.self) { _ = try key.sign(data: Data("message".utf8)) }
        #expect(throws: CardanoCoreError.self) {
            let _: PaymentExtendedVerificationKey = try key.toVerificationKey()
        }
    }

    @Test("A well-formed 128-byte key still round-trips, signs and derives its key")
    func wellFormedKeyWorks() throws {
        let key = try PaymentExtendedSigningKey.generate()
        let json = try #require(try key.toTextEnvelope())
        let restored = try PaymentExtendedSigningKey.fromTextEnvelope(json, validateType: true)
        #expect(restored.payload.count == 128)
        let signature = try restored.sign(data: Data("message".utf8))
        #expect(signature.count == 64)
        let vkey: PaymentExtendedVerificationKey = try restored.toVerificationKey()
        #expect(vkey.payload.count == 64)
        #expect(try vkey.verify(signature: signature, data: Data("message".utf8)))
    }

    @Test("SigningKeyType reads 32 bytes as a plain key")
    func signingKeyTypeReadsPlainKey() throws {
        var cbor = Data([0x58, 0x20])
        cbor.append(Data(repeating: 0x11, count: 32))
        let keyType = try SigningKeyType.fromCBOR(data: cbor)
        guard case .signingKey(let key) = keyType else {
            Issue.record("Expected a plain signing key, got \(keyType)")
            return
        }
        #expect(key.payload == Data(repeating: 0x11, count: 32))
        let vkey = try keyType.toVerificationKeyType()
        #expect(vkey.payload.count == 32)
        #expect(try keyType.sign(data: Data("message".utf8)).count == 64)
    }

    @Test("SigningKeyType reads 128 bytes as an extended key")
    func signingKeyTypeReadsExtendedKey() throws {
        let key = try PaymentExtendedSigningKey.generate()
        let keyType = try SigningKeyType(from: .bytes(key.payload))
        guard case .extendedSigningKey = keyType else {
            Issue.record("Expected an extended signing key, got \(keyType)")
            return
        }
        #expect(try keyType.toVerificationKeyType().payload.count == 32)
    }

    @Test("SigningKeyType rejects every other length", arguments: [0, 31, 33, 64, 80, 96, 127, 129])
    func signingKeyTypeRejectsOtherLengths(count: Int) {
        #expect(throws: CardanoCoreError.self) {
            _ = try SigningKeyType(from: .bytes(Data(repeating: 0x11, count: count)))
        }
    }
}

@Suite struct HDWalletSeedLengthTests {
    @Test("fromSeed(seed:) rejects empty, odd-length and non-hex strings",
          arguments: ["", "zz", "abc", "+1" + String(repeating: "11", count: 95),
                      String(repeating: "zz", count: 96), String(repeating: "1", count: 191)])
    func rejectsInvalidHex(seed: String) {
        #expect(throws: CardanoCoreError.self) { _ = try HDWallet.fromSeed(seed: seed) }
    }

    @Test("fromSeed(seedData:) requires exactly 96 bytes",
          arguments: [0, 31, 32, 40, 64, 95, 97, 128])
    func rejectsWrongLengths(count: Int) {
        let seed = Data(repeating: 1, count: count)
        #expect(throws: CardanoCoreError.self) { _ = try HDWallet.fromSeed(seedData: seed) }
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.fromSeed(seed: seed.hexEncodedString())
        }
    }

    @Test("tweakBits throws on a seed shorter than 32 bytes", arguments: [0, 1, 31])
    func tweakBitsRejectsShortSeed(count: Int) {
        #expect(throws: CardanoCoreError.self) {
            _ = try HDWallet.tweakBits(seed: Data(repeating: 0xFF, count: count))
        }
    }

    @Test("A 96-byte seed gives a 32-byte chain code, as from a mnemonic")
    func ninetySixByteSeedWorks() throws {
        let fromData = try HDWallet.fromSeed(seedData: Data(repeating: 1, count: 96))
        #expect(fromData.chainCode.count == 32)
        #expect(fromData.xPrivateKey.count == 64)
        let fromHex = try HDWallet.fromSeed(seed: Data(repeating: 1, count: 96).hexEncodedString())
        #expect(fromHex.chainCode == fromData.chainCode)
        #expect(fromHex.xPrivateKey == fromData.xPrivateKey)
    }
}

@Suite struct KeyTypeEnvelopeLoaderTests {
    @Test("VerificationKeyType.load rejects a signing key file")
    func verificationLoaderRejectsSigningKey() throws {
        let path = temporaryKeyPath("skey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try PaymentSigningKey(payload: Data(repeating: 0x33, count: 32)).save(to: path)
        #expect(throws: CardanoCoreError.self) { _ = try VerificationKeyType.load(from: path) }
    }

    @Test("VerificationKeyType.load rejects an extended signing key file")
    func verificationLoaderRejectsExtendedSigningKey() throws {
        let path = temporaryKeyPath("skey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try PaymentExtendedSigningKey.generate().save(to: path)
        #expect(throws: CardanoCoreError.self) { _ = try VerificationKeyType.load(from: path) }
    }

    @Test("SigningKeyType.load rejects a verification key file")
    func signingLoaderRejectsVerificationKey() throws {
        let path = temporaryKeyPath("vkey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try PaymentKeyPair.generate().verificationKey.save(to: path)
        #expect(throws: CardanoCoreError.self) { _ = try SigningKeyType.load(from: path) }
    }

    @Test("SigningKeyType.load rejects an extended verification key file")
    func signingLoaderRejectsExtendedVerificationKey() throws {
        let path = temporaryKeyPath("vkey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vkey: PaymentExtendedVerificationKey = try PaymentExtendedSigningKey.generate().toVerificationKey()
        try vkey.save(to: path)
        #expect(throws: CardanoCoreError.self) { _ = try SigningKeyType.load(from: path) }
    }

    @Test("A 32-byte verification key file loads as a plain verification key")
    func plainVerificationKeyLoads() throws {
        let path = temporaryKeyPath("vkey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vkey = try PaymentKeyPair.generate().verificationKey
        try vkey.save(to: path)
        let loaded = try VerificationKeyType.load(from: path)
        guard case .verificationKey(let key) = loaded else {
            Issue.record("Expected a plain verification key, got \(loaded)")
            return
        }
        #expect(key.payload == vkey.payload)
        #expect(key.type == PaymentVerificationKey.TYPE)
    }

    @Test("A 64-byte extended verification key file loads as an extended key")
    func extendedVerificationKeyLoads() throws {
        let path = temporaryKeyPath("vkey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vkey: PaymentExtendedVerificationKey = try PaymentExtendedSigningKey.generate().toVerificationKey()
        try vkey.save(to: path)
        let loaded = try VerificationKeyType.load(from: path)
        guard case .extendedVerificationKey(let key) = loaded else {
            Issue.record("Expected an extended verification key, got \(loaded)")
            return
        }
        #expect(key.payload == vkey.payload)
    }

    @Test("Plain and extended signing key files load as their own kinds")
    func signingKeysLoad() throws {
        let plainPath = temporaryKeyPath("skey")
        let extendedPath = temporaryKeyPath("skey")
        defer {
            try? FileManager.default.removeItem(atPath: plainPath)
            try? FileManager.default.removeItem(atPath: extendedPath)
        }
        let plain = try PaymentSigningKey.generate()
        let extended = try PaymentExtendedSigningKey.generate()
        try plain.save(to: plainPath)
        try extended.save(to: extendedPath)

        guard case .signingKey(let plainKey) = try SigningKeyType.load(from: plainPath) else {
            Issue.record("Expected a plain signing key")
            return
        }
        #expect(plainKey.payload == plain.payload)
        guard case .extendedSigningKey(let extendedKey) = try SigningKeyType.load(from: extendedPath) else {
            Issue.record("Expected an extended signing key")
            return
        }
        #expect(extendedKey.payload == extended.payload)
    }

    @Test("A verification key envelope with a key of the wrong length is rejected")
    func verificationLoaderRejectsWrongLength() throws {
        let path = temporaryKeyPath("vkey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let json = try envelope(type: PaymentVerificationKey.TYPE, payload: Data(repeating: 1, count: 40))
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        #expect(throws: CardanoCoreError.self) { _ = try VerificationKeyType.load(from: path) }
    }

    @Test("A signing key envelope with a key of the wrong length is rejected")
    func signingLoaderRejectsWrongLength() throws {
        let path = temporaryKeyPath("skey")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let json = try envelope(type: PaymentExtendedSigningKey.TYPE, payload: Data(repeating: 1, count: 80))
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        #expect(throws: CardanoCoreError.self) { _ = try SigningKeyType.load(from: path) }
    }
}
