import Foundation
import OrderedCollections
import CBORCodable
import Testing

@testable import SwiftCardanoCore

@Suite struct CostModelsTests {
    @Test("Initialize with all Plutus versions")
    func testInitFromDictionary() async throws {
        // Test initialization with all Plutus versions
        let testData: [Int: OrderedDictionary<String, Int64>] = [
            0: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
            1: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
            2: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            ),
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
        let testData: [Int: OrderedDictionary<String, Int64>] = [
            0: OrderedDictionary(
                uniqueKeysWithValues: ["addInteger-cpu-arguments-intercept": 100788]
            )
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
        #expect(
            costModels.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"] == 20_000_000_000)
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
        #expect(
            decoded.plutusV1?["addInteger-cpu-arguments-intercept"]
                == costModels.plutusV1?["addInteger-cpu-arguments-intercept"])
        #expect(
            decoded.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"]
                == costModels.plutusV2?["verifyEcdsaSecp256k1Signature-cpu-arguments"])
        #expect(
            decoded.plutusV3?["bls12_381_G1_add-cpu-arguments"]
                == costModels.plutusV3?["bls12_381_G1_add-cpu-arguments"])
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

    @Test("CBOR encoding with v1-only list input keeps one model")
    func testCBORCodingFromListInputV1Only() throws {
        var v1Values = Array(PLUTUS_V1_COST_MODEL.values)
        v1Values[0] = 100788
        v1Values[1] = 420

        let costModels = try CostModels([0: v1Values])
        let encoded = try costModels.toCBORData(deterministic: true)
        let hex = encoded.toHex

        #expect(hex.hasPrefix("a14100"))
        #expect(!hex.contains("4101"))
        #expect(!hex.contains("4102"))

        let decoded = try CostModels.fromCBOR(data: encoded)
        #expect(decoded.plutusV1?["addInteger-cpu-arguments-intercept"] == 100788)
        #expect(decoded.plutusV1?["addInteger-cpu-arguments-slope"] == 420)
        #expect(decoded.plutusV2 == nil)
        #expect(decoded.plutusV3 == nil)
    }

    @Test("Cost model pycardano vector round-trip")
    func testCostModelPycardanoVectorRoundTrip() throws {
        let expectedHex =
            "a141005901a69f1a000189b41901a401011903e818ad00011903e819ea350401192baf18201a000312591920a404193e801864193e801864193e801864193e801864193e801864193e80186418641864193e8018641a000170a718201a00020782182019f016041a0001194a18b2000119568718201a0001643519030104021a00014f581a00037c71187a0001011903e819a7a90402195fe419733a1826011a000db464196a8f0119ca3f19022e011999101903e819ecb2011a00022a4718201a000144ce1820193bc318201a0001291101193371041956540a197147184a01197147184a0119a9151902280119aecd19021d0119843c18201a00010a9618201a00011aaa1820191c4b1820191cdf1820192d1a18201a00014f581a00037c71187a0001011a0001614219020700011a000122c118201a00014f581a00037c71187a0001011a00014f581a00037c71187a0001011a0004213c19583c041a00163cad19fc3604194ff30104001a00022aa818201a000189b41901a401011a00013eff182019e86a1820194eae182019600c1820195108182019654d182019602f18201a032e93af1937fd0aff"

        let decoded = try CostModels.fromCBOR(data: Data(hex: expectedHex))
        let reencoded = try decoded.toCBORData(deterministic: true)
        #expect(reencoded.toHex == expectedHex)
    }

    @Test("CostModels prints JSON instead of type dump")
    func testCostModelsDescriptionIsJSON() throws {
        var v1Values = Array(PLUTUS_V1_COST_MODEL.values)
        v1Values[0] = 100788
        v1Values[1] = 420

        let costModels = try CostModels([0: v1Values])
        let printed = String(describing: Optional(costModels))

        #expect(printed.contains("\"plutusV1\""))
        #expect(!printed.contains("SwiftCardanoCore.CostModels("))
    }
}

// MARK: - Language views encoding

@Suite("CostModels language views")
struct CostModelsLanguageViewTests {

    /// The ledger's language-views encoding, which `script_data_hash` is taken
    /// over: PlutusV2 and PlutusV3 use an unsigned-integer key and a
    /// definite-length array of costs.
    @Test("PlutusV3 encodes as an integer key and a definite-length array")
    func plutusV3LanguageView() throws {
        let values: [Int64] = [1, 2, 3]
        let models = try CostModels([2: values])
        let bytes = try models.toCBORData()

        // a1 -> map(1), 02 -> key uint 2, 83 -> definite array(3), then the costs.
        #expect(bytes.toHex == "a10283010203")
    }

    @Test("PlutusV2 encodes as an integer key and a definite-length array")
    func plutusV2LanguageView() throws {
        let models = try CostModels([1: [7, 8]])
        let bytes = try models.toCBORData()
        #expect(bytes.toHex == "a101820708")
    }

    /// PlutusV1 keeps the ledger's legacy shape (cardano-ledger#2512): a
    /// byte-string key holding the language id, and a byte string holding the
    /// serialised cost model.
    @Test("PlutusV1 keeps its legacy byte-string encoding")
    func plutusV1LanguageView() throws {
        let models = try CostModels([0: [1, 2]])
        let bytes = try models.toCBORData()
        #expect(bytes.toHex.hasPrefix("a14100"))
    }

    @Test("integer keys sort before the longer PlutusV1 byte-string key")
    func canonicalKeyOrder() throws {
        let models = try CostModels([0: [1], 1: [2], 2: [3]])
        let hex = try models.toCBORData().toHex
        let v2KeyIndex = try #require(hex.range(of: "01")?.lowerBound)
        let v1KeyIndex = try #require(hex.range(of: "4100")?.lowerBound)
        #expect(v2KeyIndex < v1KeyIndex)
    }

    @Test("a language view round-trips back to the same values")
    func languageViewRoundTrip() throws {
        let values: [Int64] = [10, 20, 30, 40]
        let models = try CostModels([2: values])
        let decoded = try CostModels.fromCBOR(data: try models.toCBORData())
        #expect(Array(try #require(decoded.plutusV3).values) == values)
    }
}

// MARK: - Cost model length

@Suite("CostModels length tolerance")
struct CostModelsLengthTests {

    /// Cost models grow with every Plutus release. Rejecting an array that is
    /// longer than the built-in template makes the library unable to read
    /// current protocol parameters at all.
    @Test("a cost model longer than the built-in template is accepted in order")
    func longerThanTemplate() throws {
        let template = PLUTUS_V3_COST_MODEL.count
        let values = (0..<(template + 53)).map { Int64($0) }

        let models = try CostModels([2: values])
        let decoded = Array(try #require(models.plutusV3).values)

        #expect(decoded.count == values.count)
        #expect(decoded == values)
    }

    @Test("a cost model shorter than the built-in template is accepted in order")
    func shorterThanTemplate() throws {
        let values: [Int64] = [5, 6, 7]
        let models = try CostModels([2: values])
        #expect(Array(try #require(models.plutusV3).values) == values)
    }

    @Test("an over-long cost model still encodes every value")
    func longerThanTemplateEncodes() throws {
        let values = (0..<(PLUTUS_V3_COST_MODEL.count + 10)).map { Int64($0) }
        let models = try CostModels([2: values])
        let decoded = try CostModels.fromCBOR(data: try models.toCBORData())
        #expect(Array(try #require(decoded.plutusV3).values) == values)
    }
}
