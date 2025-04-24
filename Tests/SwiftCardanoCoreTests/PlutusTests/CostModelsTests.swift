import Testing
import Foundation
import PotentCBOR
import OrderedCollections
@testable import SwiftCardanoCore


@Suite struct CostModelsTests {
    @Test("Initialize with all Plutus versions")
    func testInitFromDictionary() async throws {
        // Test initialization with all Plutus versions
        let testData: [Int: OrderedDictionary<String, Int>] = [
            0: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
            1: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
            2: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            )
        ]
        
        let costModels = try CostModels(testData)
        
        #expect(costModels.plutusV1 != nil)
        #expect(costModels.plutusV2 != nil)
        #expect(costModels.plutusV3 != nil)
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-intercept"] == 100788)
        #expect(costModels.plutusV2?["addInteger-cpu-arguments-intercept"] == 100788)
        #expect(costModels.plutusV3?["addInteger-cpu-arguments-intercept"] == 100788)
    }
    
    @Test("Initialize with missing Plutus versions")
    func testInitWithMissingVersions() async throws {
        // Test initialization with missing Plutus versions
        let testData: [Int: OrderedDictionary<String, Int>] = [
            0: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
        ]
        
        let costModels = try CostModels(testData)
        
        #expect(costModels.plutusV1 != nil)
        #expect(costModels.plutusV2 == nil)
        #expect(costModels.plutusV3 == nil)
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-intercept"] == 100788)
    }
    
    @Test("Initialize from static data")
    func testFromStaticData() async throws {
        // Test initialization from static data
        let costModels = try CostModels.fromStaticData()
        
        // Test PlutusV1 values
        #expect(costModels.plutusV1 != nil)
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-intercept"] == 197209)
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-slope"] == 0)
        
        // Test PlutusV2 values
        #expect(costModels.plutusV2 != nil)
        #expect(costModels.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"] == 20000000000)
        #expect(costModels.plutusV2?["serialiseData-cpu-arguments-slope"] == 392670)
        
        // Test PlutusV3 values
        #expect(costModels.plutusV3 != nil)
        #expect(costModels.plutusV3?["bls12_381_G1_add-cpu-arguments"] == 962335)
        #expect(costModels.plutusV3?["bls12_381_G1_add-memory-arguments"] == 18)
    }
    
    @Test("Test coding keys and JSON encoding/decoding")
    func testJSONCoding() async throws {
        // Test that coding keys are properly mapped
        let costModels = try CostModels.fromStaticData()
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(costModels)
        
        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CostModels.self, from: encoded)
        
        // Verify the decoded data matches the original
        #expect(decoded.plutusV1?["addInteger-cpu-arguments-intercept"] == costModels.plutusV1?["addInteger-cpu-arguments-intercept"])
        #expect(decoded.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"] == costModels.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"])
        #expect(decoded.plutusV3?["bls12_381_G1_add-cpu-arguments"] == costModels.plutusV3?["bls12_381_G1_add-cpu-arguments"])
    }
    
    @Test("Test CBOR encoding/decoding")
    func testCBORCoding() async throws {
        // Test that coding keys are properly mapped
        let costModels = try CostModels.forScriptDataHash()
        
        // Encode to CBOR
        let encoder = CBOREncoder()
        encoder.deterministic = true
        let encoded = try encoder.encode(costModels)
        
        // Decode back
        let decoder = CBORDecoder()
        let decoded = try decoder.decode(CostModels.self, from: encoded)
        
        let expectedCborHex = """
            a141005901d59f1a000302590001011a00060bc719026d00011a000249f01903e800011a000249f018201a0025cea81971f70419744d186419744d186419744d186419744d186419744d186419744d18641864186419744d18641a000249f018201a000249f018201a000249f018201a000249f01903e800011a000249f018201a000249f01903e800081a000242201a00067e2318760001011a000249f01903e800081a000249f01a0001b79818f7011a000249f0192710011a0002155e19052e011903e81a000249f01903e8011a000249f018201a000249f018201a000249f0182001011a000249f0011a000249f0041a000194af18f8011a000194af18f8011a0002377c190556011a0002bdea1901f1011a000249f018201a000249f018201a000249f018201a000249f018201a000249f018201a000249f018201a000242201a00067e23187600010119f04c192bd200011a000249f018201a000242201a00067e2318760001011a000242201a00067e2318760001011a0025cea81971f704001a000141bb041a000249f019138800011a000249f018201a000302590001011a000249f018201a000249f018201a000249f018201a000249f018201a000249f018201a000249f018201a000249f018201a00330da70101ff
            """
        
        // Verify the decoded data matches the original
        #expect(encoded.toHex == expectedCborHex)
        #expect(costModels == decoded)
    }
}
