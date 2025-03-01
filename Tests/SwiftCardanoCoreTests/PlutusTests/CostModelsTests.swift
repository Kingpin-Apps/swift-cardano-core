import Testing
import Foundation
@testable import SwiftCardanoCore


@Suite struct CostModelsTests {
    @Test("Initialize with all Plutus versions")
    func testInitFromDictionary() async throws {
        // Test initialization with all Plutus versions
        let testData: [AnyHashable: AnyHashable] = [
            0: ["addInteger-cpu-arguments-intercept": 100788],
            1: ["addInteger-cpu-arguments-intercept": 100788],
            2: ["addInteger-cpu-arguments-intercept": 100788]
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
        let testData: [AnyHashable: AnyHashable] = [
            0: ["addInteger-cpu-arguments-intercept": 100788]
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
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-intercept"] == 100788)
        #expect(costModels.plutusV1?["addInteger-cpu-arguments-slope"] == 420)
        
        // Test PlutusV2 values
        #expect(costModels.plutusV2 != nil)
        #expect(costModels.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"] == 43053543)
        #expect(costModels.plutusV2?["serialiseData-cpu-arguments-slope"] == 213312)
        
        // Test PlutusV3 values
        #expect(costModels.plutusV3 != nil)
        #expect(costModels.plutusV3?["bls12_381_G1_add-cpu-arguments"] == 962335)
        #expect(costModels.plutusV3?["bls12_381_G1_add-memory-arguments"] == 18)
    }
    
    @Test("Test coding keys and JSON encoding/decoding")
    func testCodingKeys() async throws {
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
}
