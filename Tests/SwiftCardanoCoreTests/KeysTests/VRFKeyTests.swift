import Foundation
import Testing
import SwiftNcal
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Test Suite
@Suite struct VRFSigningKeyTests {
    @Test func testKeyGeneration() async throws {
        let sk = try VRFSigningKey.generate()
        #expect(sk.payload.count > 0)
        #expect(sk._type == VRFSigningKey.TYPE)
        #expect(sk._description == VRFSigningKey.DESCRIPTION)
    }

    @Test func testToVerificationKey() async throws {
        let sk = try VRFSigningKey.generate()
        let vk = try sk.toVerificationKey()
        #expect(vk.payload.count > 0)
        #expect(vk._type == VRFVerificationKey.TYPE)
    }

    @Test func testSignThrowsError() async throws {
        let sk = try VRFSigningKey.generate()
        let message = "Test message".data(using: .utf8)!

        // VRF keys do not support signing, should throw invalidOperation
        #expect(throws: CardanoCoreError.self) {
            _ = try sk.sign(data: message)
        }
    }

    @Test func testProve() async throws {
        let sk = try VRFSigningKey.generate()
        let message = "Test message for VRF proof".data(using: .utf8)!

        let proof = try sk.prove(message: message)
        #expect(proof.count == VRFCert.PROOF_SIZE)
    }

    @Test func testProveConsistency() async throws {
        let sk = try VRFSigningKey.generate()
        let message = "Consistent message".data(using: .utf8)!

        // Same message should produce same proof
        let proof1 = try sk.prove(message: message)
        let proof2 = try sk.prove(message: message)
        #expect(proof1 == proof2)
    }

    @Test func testProveDifferentMessages() async throws {
        let sk = try VRFSigningKey.generate()
        let message1 = "Message one".data(using: .utf8)!
        let message2 = "Message two".data(using: .utf8)!

        let proof1 = try sk.prove(message: message1)
        let proof2 = try sk.prove(message: message2)
        #expect(proof1 != proof2)
    }

    @Test func testCertify() async throws {
        let sk = try VRFSigningKey.generate()
        let message = "Test message for VRF certificate".data(using: .utf8)!

        let cert = try sk.certify(message: message)
        #expect(cert.output.count > 0)
        #expect(cert.proof.count == VRFCert.PROOF_SIZE)
    }

    @Test func testCertifyConsistency() async throws {
        let sk = try VRFSigningKey.generate()
        let message = "Consistent cert message".data(using: .utf8)!

        // Same message should produce same certificate
        let cert1 = try sk.certify(message: message)
        let cert2 = try sk.certify(message: message)
        #expect(cert1 == cert2)
    }

    @Test func testCustomTypeAndDescription() async throws {
        let vrfKeyPair = SwiftNcal.VRFKeyPair.generate()
        let customType = "CustomVRFType"
        let customDescription = "Custom VRF Description"
        let sk = VRFSigningKey(
            payload: vrfKeyPair.signingKey.bytes,
            type: customType,
            description: customDescription
        )
        #expect(sk._type == customType)
        #expect(sk._description == customDescription)
    }
}

@Suite struct VRFVerificationKeyTests {
    @Test func testFromSigningKey() async throws {
        let sk = try VRFSigningKey.generate()
        let vk = try VRFVerificationKey.fromSigningKey(sk)
        #expect(vk.payload.count > 0)
        #expect(vk._type == VRFVerificationKey.TYPE)
        #expect(vk._description == VRFVerificationKey.DESCRIPTION)
    }

    @Test func testHash() async throws {
        let sk = try VRFSigningKey.generate()
        let vk = try sk.toVerificationKey()
        let hash = try vk.hash()
        #expect(hash.payload.count == VRF_KEY_HASH_SIZE)
    }

    @Test func testHashConsistency() async throws {
        let sk = try VRFSigningKey.generate()
        let vk = try sk.toVerificationKey()

        let hash1 = try vk.hash()
        let hash2 = try vk.hash()
        #expect(hash1 == hash2)
    }

    @Test func testDifferentKeysProduceDifferentHashes() async throws {
        let sk1 = try VRFSigningKey.generate()
        let sk2 = try VRFSigningKey.generate()
        let vk1 = try sk1.toVerificationKey()
        let vk2 = try sk2.toVerificationKey()

        let hash1 = try vk1.hash()
        let hash2 = try vk2.hash()
        #expect(hash1 != hash2)
    }

    @Test func testCustomTypeAndDescription() async throws {
        let vrfKeyPair = SwiftNcal.VRFKeyPair.generate()
        let customType = "CustomVRFVKeyType"
        let customDescription = "Custom VRF VKey Description"
        let vk = VRFVerificationKey(
            payload: vrfKeyPair.verifyingKey.bytes,
            type: customType,
            description: customDescription
        )
        #expect(vk._type == customType)
        #expect(vk._description == customDescription)
    }
}

@Suite struct VRFKeyPairTests {
    @Test func testGenerate() async throws {
        let kp = try SwiftCardanoCore.VRFKeyPair.generate()
        #expect(kp.signingKey.payload.count > 0)
        #expect(kp.verificationKey.payload.count > 0)
    }

    @Test func testFromSigningKey() async throws {
        let sk = try VRFSigningKey.generate()
        let kp = try VRFKeyPair.fromSigningKey(sk)
        #expect(kp.signingKey == sk)

        let expectedVK = try VRFVerificationKey.fromSigningKey(sk)
        #expect(kp.verificationKey == expectedVK)
    }

    @Test func testEquality() async throws {
        let kp1 = try SwiftCardanoCore.VRFKeyPair.generate()
        let kp2 = try SwiftCardanoCore.VRFKeyPair.fromSigningKey(kp1.signingKey)
        #expect(kp1 == kp2)

        let kp3 = try SwiftCardanoCore.VRFKeyPair.generate()
        #expect(kp1 != kp3)
    }

    @Test func testProveWithKeyPair() async throws {
        let kp = try SwiftCardanoCore.VRFKeyPair.generate()
        let message = "Key pair prove test".data(using: .utf8)!

        let proof = try kp.signingKey.prove(message: message)
        #expect(proof.count == VRFCert.PROOF_SIZE)
    }

    @Test func testCertifyWithKeyPair() async throws {
        let kp = try SwiftCardanoCore.VRFKeyPair.generate()
        let message = "Key pair certify test".data(using: .utf8)!

        let cert = try kp.signingKey.certify(message: message)
        #expect(cert.output.count > 0)
        #expect(cert.proof.count == VRFCert.PROOF_SIZE)
    }

    @Test func testVerificationKeyMatchesSigningKey() async throws {
        let kp = try SwiftCardanoCore.VRFKeyPair.generate()
        let derivedVK = try kp.signingKey.toVerificationKey()
        #expect(kp.verificationKey == derivedVK)
    }
}

@Suite struct VrfKeyHashTests {
    @Test func testInitialization() async throws {
        let payload = Data(repeating: 0x01, count: VRF_KEY_HASH_SIZE)
        let hash = VrfKeyHash(payload: payload)
        #expect(hash.payload == payload)
        #expect(hash.payload.count == VRF_KEY_HASH_SIZE)
    }

    @Test func testHashFromVerificationKey() async throws {
        let sk = try VRFSigningKey.generate()
        let vk = try sk.toVerificationKey()
        let hash = try vk.hash()

        #expect(hash.payload.count == VRF_KEY_HASH_SIZE)
    }

    @Test func testHashable() async throws {
        let payload1 = Data(repeating: 0x01, count: VRF_KEY_HASH_SIZE)
        let payload2 = Data(repeating: 0x02, count: VRF_KEY_HASH_SIZE)
        let hash1 = VrfKeyHash(payload: payload1)
        let hash2 = VrfKeyHash(payload: payload1)
        let hash3 = VrfKeyHash(payload: payload2)

        #expect(hash1 == hash2)
        #expect(hash1 != hash3)

        var set: Set<VrfKeyHash> = []
        set.insert(hash1)
        set.insert(hash2)
        #expect(set.count == 1)
    }

    @Test func testSizeConstraints() async throws {
        #expect(VrfKeyHash.maxSize == VRF_KEY_HASH_SIZE)
        #expect(VrfKeyHash.minSize == VRF_KEY_HASH_SIZE)
    }
}
