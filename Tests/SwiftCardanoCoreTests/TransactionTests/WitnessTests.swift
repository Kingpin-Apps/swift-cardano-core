import Testing
import Foundation
import CBORCodable
@testable import SwiftCardanoCore

@Suite struct VerificationKeyTypeTests {
    let verificationKey = try! VerificationKey(payload: Data(repeating: 0x01, count: 32))
    let extendedVerificationKey = try! ExtendedVerificationKey(payload: Data(repeating: 0x02, count: 64))
    
    @Test func testInitialization() async throws {
        let vkeyType = VerificationKeyType.verificationKey(verificationKey)
        let extendedVkeyType = VerificationKeyType.extendedVerificationKey(extendedVerificationKey)
        
        switch vkeyType {
        case .verificationKey(let key):
            if let vkey = key as? VerificationKey {
                #expect(vkey.payload == verificationKey.payload)
            } else {
                Issue.record("Expected VKey type")
            }
        case .extendedVerificationKey:
            Issue.record("Expected verificationKey, but found extendedVerificationKey")
        }
        
        switch extendedVkeyType {
        case .verificationKey:
            Issue.record("Expected extendedVerificationKey, but found verificationKey")
        case .extendedVerificationKey(let key):
            if let extendedVkey = key as? ExtendedVerificationKey {
                #expect(extendedVkey.payload == extendedVerificationKey.payload)
            } else {
                Issue.record("Expected ExtendedVKey type")
            }
        }
    }
    
    @Test func testEncoding() async throws {
        let vkeyType: VerificationKeyType = .verificationKey(verificationKey)
        let extendedVkeyType: VerificationKeyType = .extendedVerificationKey(extendedVerificationKey)
        
        let vkeyData = try vkeyType.toCBORData()
        let extendedVkeyData = try extendedVkeyType.toCBORData()
        
        let decodedVkey = try VerificationKeyType.fromCBOR(data: vkeyData)
        let decodedExtendedVkey = try VerificationKeyType.fromCBOR(data: extendedVkeyData)
        
        #expect(decodedVkey == vkeyType)
        #expect(decodedExtendedVkey == extendedVkeyType)
    }
}

@Suite struct VerificationKeyWitnessTests {
    let verificationKey = try! VerificationKey(payload: Data(repeating: 0x01, count: 64))
    let signature = Data(repeating: 0x03, count: 64)
    
    @Test func testInitialization() async throws {
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        #expect(vkeyWitness.vkey == .verificationKey(verificationKey))
        #expect(vkeyWitness.signature == signature)
    }
    
    @Test func testEncoding() async throws {
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let encodedData = try CBOREncoder().encode(vkeyWitness)
        let decodedWitness = try CBORDecoder().decode(VerificationKeyWitness.self, from: encodedData)

        #expect(decodedWitness == vkeyWitness)
    }

    // A witness written by `cardano-cli conway transaction witness` 11.2.3.
    let cliVkey = "7da9a56144fc140072ac38229162bca3ab62c9667891e69ba647a44584285965"
    let cliSignature = "36e14373862f7014dee0223b58b7a9959a7657defacc0527d8fe82330aed22d910ddb84010ee97d584b6414c14c9ba1a241379ac7aff68ae53fda25702ecb00f"

    func envelope(_ cborHex: String) -> String {
        """
        {
            "type": "TxWitness ConwayEra",
            "description": "Key Witness ShelleyEra",
            "cborHex": "\(cborHex)"
        }
        """
    }

    @Test func testTextEnvelopeReadsBareWitness() async throws {
        let witness = try VerificationKeyWitness.fromTextEnvelope(
            envelope("825820\(cliVkey)5840\(cliSignature)"))

        #expect(witness.vkey.payload.toHex == cliVkey)
        #expect(witness.signature.toHex == cliSignature)
    }

    @Test func testTextEnvelopeReadsOlderCardanoCliWitness() async throws {
        let bare = try VerificationKeyWitness.fromTextEnvelope(
            envelope("825820\(cliVkey)5840\(cliSignature)"))
        let tagged = try VerificationKeyWitness.fromTextEnvelope(
            envelope("8200825820\(cliVkey)5840\(cliSignature)"))

        #expect(tagged == bare)
        #expect(try tagged.toTextEnvelope() == bare.toTextEnvelope())
    }

    @Test func testTextEnvelopeRejectsBootstrapWitness() async throws {
        #expect(throws: CardanoCoreError.self) {
            try VerificationKeyWitness.fromTextEnvelope(
                envelope("8201825820\(cliVkey)5840\(cliSignature)"))
        }
    }
}

@Suite struct TransactionWitnessSetTests {
    let verificationKey = try! VerificationKey(payload: Data(repeating: 0x01, count: 64))
    let signature = Data(repeating: 0x03, count: 64)
    
    @Test func testInitialization() async throws {
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses:
                    .nonEmptyOrderedSet(NonEmptyOrderedSet<VerificationKeyWitness>(
                [vkeyWitness]
            )),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        #expect(witnessSet.vkeyWitnesses?.asList.count == 1)
        #expect(witnessSet.vkeyWitnesses?.asList.first == vkeyWitness)
        #expect(witnessSet.nativeScripts == nil)
        #expect(witnessSet.bootstrapWitness == nil)
        #expect(witnessSet.plutusV1Script == nil)
        #expect(witnessSet.plutusV2Script == nil)
        #expect(witnessSet.plutusData == nil)
        #expect(witnessSet.redeemers == nil)
    }
    
    @Test func testEncoding() async throws {
        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )
        
        let witnessSet = TransactionWitnessSet(
            vkeyWitnesses: .nonEmptyOrderedSet(
                NonEmptyOrderedSet<VerificationKeyWitness>(
                    [vkeyWitness]
                )
            ),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )
        
        let encodedData = try witnessSet.toCBORData()
        let decodedWitnessSet = try TransactionWitnessSet.fromCBOR(data: encodedData)
        
        #expect(decodedWitnessSet == witnessSet)
    }
} 
