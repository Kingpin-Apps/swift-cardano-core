import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct OperationalCertificateIssueCounterTests {
    
    // Test data from the design spec example
    let exampleCborHex = "82015820b6ee6aaf452b4e538666eb892fb82e00cf119a70499b5ca3c6d4c0a0b689af4e"
    let exampleVKeyHex = "b6ee6aaf452b4e538666eb892fb82e00cf119a70499b5ca3c6d4c0a0b689af4e"
    
    // MARK: - Initialization Tests
    
    @Test("Test initialization with counter value and verification key")
    func testInitialization() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter(
            counterValue: 0,
            coldVerificationKey: vkey
        )
        
        #expect(counter.counterValue == 0)
        #expect(counter.coldVerificationKey == vkey)
        #expect(counter._type == "NodeOperationalCertificateIssueCounter")
        #expect(counter._description == "Next certificate issue number: 0")
    }
    
    // MARK: - Factory Method Tests
    
    @Test("Test createNewCounter factory method")
    func testCreateNewCounter() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: vkey
        )
        
        #expect(counter.counterValue == 0)
        #expect(counter.coldVerificationKey == vkey)
    }
    
    @Test("Test createNewCounter with generated StakePoolKeyPair")
    func testCreateNewCounterWithKeyPair() async throws {
        let keyPair = try StakePoolKeyPair.generate()
        let counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: keyPair.verificationKey
        )
        
        #expect(counter.counterValue == 0)
        #expect(counter.coldVerificationKey == keyPair.verificationKey)
    }
    
    // MARK: - Counter Operations Tests
    
    @Test("Test increment operation")
    func testIncrement() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        var counter = try OperationalCertificateIssueCounter(
            counterValue: 0,
            coldVerificationKey: vkey
        )
        
        try counter.increment()
        #expect(counter.counterValue == 1)
        #expect(counter._description == "Next certificate issue number: 1")
        
        try counter.increment()
        #expect(counter.counterValue == 2)
        #expect(counter._description == "Next certificate issue number: 2")
    }
    
    // MARK: - CBOR Serialization Tests
    
    @Test("Test CBOR encoding and decoding roundtrip")
    func testCBORRoundtrip() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let original = try OperationalCertificateIssueCounter(
            counterValue: 5,
            coldVerificationKey: vkey
        )
        
        let cborData = try CBOREncoder().encode(original)
        let decoded = try CBORDecoder().decode(OperationalCertificateIssueCounter.self, from: cborData)
        
        #expect(decoded.counterValue == original.counterValue)
        #expect(decoded.coldVerificationKey == original.coldVerificationKey)
    }
    
    @Test("Test CBOR hex decoding from example")
    func testCBORHexDecoding() async throws {
        let expectedVKey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter.fromCBORHex(exampleCborHex)
        
        #expect(counter.counterValue == 1)
        #expect(counter.coldVerificationKey == expectedVKey)
    }
    
    @Test("Test CBOR hex encoding matches expected format")
    func testCBORHexEncoding() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        
        let cborHex = try counter.toCBORHex()
        #expect(cborHex == exampleCborHex)
    }
    
    // MARK: - TextEnvelope Tests
    
    @Test("Test TextEnvelope serialization")
    func testTextEnvelopeSerialization() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        
        let json = try counter.toTextEnvelope()
        #expect(json != nil)
        #expect(json!.contains("\"type\": \"NodeOperationalCertificateIssueCounter\""))
        #expect(json!.contains("\"description\": \"Next certificate issue number: 1\""))
        #expect(json!.contains("\"cborHex\": \"\(exampleCborHex)\""))
    }
    
    @Test("Test TextEnvelope deserialization")
    func testTextEnvelopeDeserialization() async throws {
        let json = """
        {
            "type": "NodeOperationalCertificateIssueCounter",
            "description": "Next certificate issue number: 1",
            "cborHex": "\(exampleCborHex)"
        }
        """
        
        let expectedVKey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter = try OperationalCertificateIssueCounter.fromTextEnvelope(json)
        
        #expect(counter.counterValue == 1)
        #expect(counter.coldVerificationKey == expectedVKey)
        #expect(counter._type == "NodeOperationalCertificateIssueCounter")
        #expect(counter._description == "Next certificate issue number: 1")
    }
    
    // MARK: - Validation Tests
    
    @Test("Test validateVerificationKey with matching key")
    func testValidateVerificationKeyMatching() async throws {
        let keyPair = try StakePoolKeyPair.generate()
        let counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: keyPair.verificationKey
        )
        
        #expect(counter.validateVerificationKey(keyPair.verificationKey))
    }
    
    @Test("Test validateVerificationKey with non-matching key")
    func testValidateVerificationKeyNonMatching() async throws {
        let keyPair1 = try StakePoolKeyPair.generate()
        let keyPair2 = try StakePoolKeyPair.generate()
        
        let counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: keyPair1.verificationKey
        )
        
        #expect(!counter.validateVerificationKey(keyPair2.verificationKey))
    }
    
    // MARK: - Equatable & Hashable Tests
    
    @Test("Test equality")
    func testEquality() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter1 = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        let counter2 = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        let counter3 = try OperationalCertificateIssueCounter(
            counterValue: 2,
            coldVerificationKey: vkey
        )
        
        #expect(counter1 == counter2)
        #expect(counter1 != counter3)
    }
    
    @Test("Test hashing")
    func testHashing() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let counter1 = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        let counter2 = try OperationalCertificateIssueCounter(
            counterValue: 1,
            coldVerificationKey: vkey
        )
        
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        
        counter1.hash(into: &hasher1)
        counter2.hash(into: &hasher2)
        
        #expect(hasher1.finalize() == hasher2.finalize())
    }
    
    // MARK: - JSONSerializable Tests
    
    @Test("Test JSON serialization roundtrip")
    func testJSONRoundtrip() async throws {
        let vkey = try StakePoolVerificationKey(payload: exampleVKeyHex.hexStringToData)
        let original = try OperationalCertificateIssueCounter(
            counterValue: 3,
            coldVerificationKey: vkey
        )
        
        let json = try original.toJSON()
        #expect(json != nil)
        
        let decoded = try OperationalCertificateIssueCounter.fromJSON(json!)
        
        #expect(decoded.counterValue == original.counterValue)
        #expect(decoded.coldVerificationKey == original.coldVerificationKey)
    }
}
