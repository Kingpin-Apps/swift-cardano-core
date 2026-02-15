import Foundation
import Testing
import SwiftKES
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Test Suite
@Suite struct KESSigningKeyTests {
    @Test func testKeyGeneration() async throws {
        let sk = try KESSigningKey.generate()
        #expect(sk.payload.count > 0)
        #expect(sk.currentPeriod == 0)
        #expect(sk._type == KESSigningKey.TYPE)
        #expect(sk._description == KESSigningKey.DESCRIPTION)
    }

    @Test func testFromSeed() async throws {
        let seed = Data(repeating: 0x42, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        #expect(sk.payload.count > 0)
        #expect(sk.currentPeriod == 0)

        // Same seed should produce same key
        let sk2 = try KESSigningKey.fromSeed(seed)
        #expect(sk.payload == sk2.payload)
    }

    @Test func testToVerificationKey() async throws {
        let sk = try KESSigningKey.generate()
        let vk = try sk.toVerificationKey()
        #expect(vk.payload.count == KESConstants.publicKeySize)
    }

    @Test func testSignAndVerify() async throws {
        let seed = Data(repeating: 0x01, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        let vk = try sk.toVerificationKey()
        let message = "Test message for KES signing".data(using: .utf8)!

        let signature = try sk.sign(data: message)
        #expect(signature.count == KES_SIGNATURE_SIZE)

        let isValid = try vk.verify(signature: signature, message: message, period: sk.currentPeriod)
        #expect(isValid)
    }

    @Test func testSignWithPeriod() async throws {
        let seed = Data(repeating: 0x02, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        let message = "Test message".data(using: .utf8)!

        let (signature, period) = try sk.signWithPeriod(data: message)
        #expect(signature.count == KES_SIGNATURE_SIZE)
        #expect(period == 0)
    }

    @Test func testEvolve() async throws {
        let seed = Data(repeating: 0x03, count: 32)
        var sk = try KESSigningKey.fromSeed(seed)
        let vk = try sk.toVerificationKey()
        let originalPayload = sk.payload

        #expect(sk.currentPeriod == 0)
        #expect(sk.canEvolve)

        try sk.evolve()
        #expect(sk.currentPeriod == 1)
        #expect(sk.payload != originalPayload)
        #expect(sk.canEvolve)

        // Verify signature works at new period
        let message = "Test after evolve".data(using: .utf8)!
        let signature = try sk.sign(data: message)
        let isValid = try vk.verify(signature: signature, message: message, period: sk.currentPeriod)
        #expect(isValid)
    }

    @Test func testTotalPeriods() async throws {
        #expect(KESSigningKey.totalPeriods == 64)
    }

    @Test func testInitWithPeriod() async throws {
        let payload = Data(repeating: 0x00, count: 608) // Sum6KES secret key size
        let sk = KESSigningKey(payload: payload, period: 5, type: nil, description: nil)
        #expect(sk.currentPeriod == 5)
    }

    @Test func testCustomTypeAndDescription() async throws {
        let payload = Data(repeating: 0x00, count: 608)
        let customType = "CustomKESType"
        let customDescription = "Custom KES Description"
        let sk = KESSigningKey(payload: payload, type: customType, description: customDescription)
        #expect(sk._type == customType)
        #expect(sk._description == customDescription)
    }
}

@Suite struct KESVerificationKeyKeyTests {
    @Test func testFromSigningKey() async throws {
        let sk = try KESSigningKey.generate()
        let vk = try KESVerificationKey.fromSigningKey(sk)
        #expect(vk.payload.count == KESConstants.publicKeySize)
        #expect(vk._type == KESVerificationKey.TYPE)
        #expect(vk._description == KESVerificationKey.DESCRIPTION)
    }

    @Test func testHash() async throws {
        let sk = try KESSigningKey.generate()
        let vk = try sk.toVerificationKey()
        let hash = try vk.hash()
        #expect(hash.payload.count == KES_KEY_HASH_SIZE)
    }

    @Test func testVerifyValidSignature() async throws {
        let seed = Data(repeating: 0x04, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        let vk = try sk.toVerificationKey()
        let message = "Valid signature test".data(using: .utf8)!

        let signature = try sk.sign(data: message)
        let isValid = try vk.verify(signature: signature, message: message, period: 0)
        #expect(isValid)
    }

    @Test func testVerifyInvalidSignature() async throws {
        let seed = Data(repeating: 0x05, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        let vk = try sk.toVerificationKey()
        let message = "Original message".data(using: .utf8)!

        let signature = try sk.sign(data: message)

        // Verify with wrong message
        let wrongMessage = "Wrong message".data(using: .utf8)!
        let isValid = try vk.verify(signature: signature, message: wrongMessage, period: 0)
        #expect(!isValid)
    }

    @Test func testVerifyWrongPeriod() async throws {
        let seed = Data(repeating: 0x06, count: 32)
        let sk = try KESSigningKey.fromSeed(seed)
        let vk = try sk.toVerificationKey()
        let message = "Period test".data(using: .utf8)!

        let signature = try sk.sign(data: message)

        // Verify with wrong period
        let isValid = try vk.verify(signature: signature, message: message, period: 1)
        #expect(!isValid)
    }

    @Test func testCBORRoundTrip() async throws {
        let sk = try KESSigningKey.generate()
        let vk = try sk.toVerificationKey()
        try checkTwoWayCBOR(serializable: vk)
    }

    @Test func testPrimitiveRoundTrip() async throws {
        let sk = try KESSigningKey.generate()
        let vk = try sk.toVerificationKey()
        let primitive = vk.toPrimitive()
        let restored = try KESVerificationKey(from: primitive)
        #expect(restored == vk)
    }

    @Test func testCustomTypeAndDescription() async throws {
        let payload = Data(repeating: 0x00, count: KESConstants.publicKeySize)
        let customType = "CustomKESVKeyType"
        let customDescription = "Custom KES VKey Description"
        let vk = KESVerificationKey(payload: payload, type: customType, description: customDescription)
        #expect(vk._type == customType)
        #expect(vk._description == customDescription)
    }
}

@Suite struct KESKeyPairTests {
    @Test func testGenerate() async throws {
        let kp = try KESKeyPair.generate()
        #expect(kp.signingKey.payload.count > 0)
        #expect(kp.verificationKey.payload.count == KESConstants.publicKeySize)
        #expect(kp.signingKey.currentPeriod == 0)
    }

    @Test func testFromSeed() async throws {
        let seed = Data(repeating: 0x07, count: 32)
        let kp = try KESKeyPair.fromSeed(seed)
        #expect(kp.signingKey.payload.count > 0)
        #expect(kp.verificationKey.payload.count == KESConstants.publicKeySize)

        // Same seed should produce same key pair
        let kp2 = try KESKeyPair.fromSeed(seed)
        #expect(kp == kp2)
    }

    @Test func testFromSigningKey() async throws {
        let sk = try KESSigningKey.generate()
        let kp = try KESKeyPair.fromSigningKey(sk)
        #expect(kp.signingKey == sk)

        let expectedVK = try KESVerificationKey.fromSigningKey(sk)
        #expect(kp.verificationKey == expectedVK)
    }

    @Test func testEquality() async throws {
        let seed = Data(repeating: 0x08, count: 32)
        let kp1 = try KESKeyPair.fromSeed(seed)
        let kp2 = try KESKeyPair.fromSeed(seed)
        #expect(kp1 == kp2)

        let kp3 = try KESKeyPair.generate()
        #expect(kp1 != kp3)
    }

    @Test func testSignAndVerifyWithKeyPair() async throws {
        let kp = try KESKeyPair.generate()
        let message = "Key pair sign test".data(using: .utf8)!

        let signature = try kp.signingKey.sign(data: message)
        let isValid = try kp.verificationKey.verify(
            signature: signature,
            message: message,
            period: kp.signingKey.currentPeriod
        )
        #expect(isValid)
    }
}

@Suite struct KesKeyHashTests {
    @Test func testInitialization() async throws {
        let payload = Data(repeating: 0x01, count: KES_KEY_HASH_SIZE)
        let hash = KesKeyHash(payload: payload)
        #expect(hash.payload == payload)
        #expect(hash.payload.count == KES_KEY_HASH_SIZE)
    }

    @Test func testHashable() async throws {
        let payload1 = Data(repeating: 0x01, count: KES_KEY_HASH_SIZE)
        let payload2 = Data(repeating: 0x02, count: KES_KEY_HASH_SIZE)
        let hash1 = KesKeyHash(payload: payload1)
        let hash2 = KesKeyHash(payload: payload1)
        let hash3 = KesKeyHash(payload: payload2)

        #expect(hash1 == hash2)
        #expect(hash1 != hash3)

        var set: Set<KesKeyHash> = []
        set.insert(hash1)
        set.insert(hash2)
        #expect(set.count == 1)
    }

    @Test func testSizeConstraints() async throws {
        #expect(KesKeyHash.maxSize == KES_KEY_HASH_SIZE)
        #expect(KesKeyHash.minSize == KES_KEY_HASH_SIZE)
    }
}
