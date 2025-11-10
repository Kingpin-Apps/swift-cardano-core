import Testing
import Foundation
import PotentCBOR
import OrderedCollections
@testable import SwiftCardanoCore

// Sample metadata for testing
let validMetadata: [TransactionMetadatumLabel: TransactionMetadatum] = [
    1: .int(42),
    2: .text("Hello, Cardano!"),
    3: .bytes(Data(repeating: 0xAB, count: 10)),
    4: .list([.int(1), .text("nested")]),
    5: .map(OrderedDictionary(uniqueKeysWithValues: [(.int(1), .int(123))]))
]

@Suite struct MetadataTests {
    
    @Test("Test Metadata Encoding")
    func testEncoding() async throws {
        let metadata = try Metadata(validMetadata)
        let encoded = try CBOREncoder().encode(metadata.data)
        
        #expect(encoded.count > 0, "Encoded CBOR data should not be nil")
    }
    
    @Test("Test Metadata Decoding")
    func testDecoding() async throws {
        let metadata = try Metadata(validMetadata)
        let encoded = try metadata.toCBORData()
        let decoded = try CBORDecoder().decode([TransactionMetadatumLabel: TransactionMetadatum].self, from: encoded)
        
        #expect(decoded == metadata.data, "Decoded metadata should match the original")
    }
    
    @Test("Test Subscript Access")
    func testSubscriptAccess() async throws {
        var metadata = try Metadata(validMetadata)
        metadata[6] = .text("New Entry")
        
        #expect(metadata[6] == .text("New Entry"), "Subscript should allow adding new entries")
        #expect(metadata[1] == .int(42), "Existing entries should remain unchanged")
    }
    
    @Test("Test Empty Metadata")
    func testEmptyMetadata() async throws {
        let emptyMetadata = try Metadata([:])
        
        #expect(emptyMetadata.data.isEmpty, "Empty Metadata should have no entries")
    }
    
    @Test("Test Complex Nested Metadata")
    func testComplexNestedMetadata() async throws {
        let complexMetadata: [TransactionMetadatumLabel: TransactionMetadatum] = [
            1: .map(OrderedDictionary(uniqueKeysWithValues: [
                (.text("nestedKey"), .list([.int(99), .text("nestedValue")]))
            ]))
        ]
        
        let metadata = try Metadata(complexMetadata)
        let encoded = try CBOREncoder().encode(metadata.data)
        
        let decoded = try CBORDecoder().decode([TransactionMetadatumLabel: TransactionMetadatum].self, from: encoded)
        
        #expect(decoded == metadata.data, "Complex nested metadata should encode and decode correctly")
    }
}

@Suite struct ShelleyMaryMetadataTests {
    let sampleMetadata = try! Metadata(validMetadata)
    let sampleNativeScripts: [NativeScript] = [
        .invalidHereAfter(AfterScript(slot: 100)),
    ]
    
    @Test("Test Encoding and Decoding ShelleyMaryMetadata")
    func testEncodingDecoding() async throws {
        let shelleyMetadata = ShelleyMaryMetadata(
            metadata: sampleMetadata,
            nativeScripts: sampleNativeScripts
        )
        
        let encoded = try CBOREncoder().encode(shelleyMetadata)
        let decoded = try CBORDecoder().decode(ShelleyMaryMetadata.self, from: encoded)
        
        #expect(decoded.metadata.data == sampleMetadata.data, "Decoded metadata should match the original")
        #expect(decoded.nativeScripts == sampleNativeScripts, "Decoded native scripts should match the original")
    }
    
    @Test("Test Encoding Without Native Scripts")
    func testEncodingWithoutNativeScripts() async throws {
        let shelleyMetadata = ShelleyMaryMetadata(metadata: sampleMetadata, nativeScripts: nil)
        let encoded = try CBOREncoder().encode(shelleyMetadata)
        let decoded = try CBORDecoder().decode(ShelleyMaryMetadata.self, from: encoded)
        
        #expect(decoded.metadata.data == sampleMetadata.data, "Decoded metadata should match the original")
        #expect(decoded.nativeScripts == nil, "Decoded native scripts should be nil")
    }
}

@Suite struct AlonzoMetadataTests {
    let sampleMetadata = try! Metadata(validMetadata)
    let sampleNativeScripts: [NativeScript] = [
        .invalidHereAfter(AfterScript(slot: 100)),
    ]
    let samplePlutusScripts: [Data] = [
        Data([0xDE, 0xAD, 0xBE, 0xEF]),
        Data([0xCA, 0xFE, 0xBA, 0xBE])
    ]
    
    @Test("Test Encoding and Decoding AlonzoMetadata")
    func testEncodingDecoding() async throws {
        let plutusV1Script = samplePlutusScripts.compactMap { PlutusV1Script(data: $0) }
        let plutusV2Script = samplePlutusScripts.compactMap { PlutusV2Script(data: $0) }
        let plutusV3Script = samplePlutusScripts.compactMap { PlutusV3Script(data: $0) }
        
        let alonzoMetadata = AlonzoMetadata(
            metadata: sampleMetadata,
            nativeScripts: sampleNativeScripts,
            plutusV1Script: plutusV1Script,
            plutusV2Script: plutusV2Script,
            plutusV3Script: plutusV3Script
        )
        
        let encoded = try alonzoMetadata.toCBORData()
        let decoded = try AlonzoMetadata.fromCBOR(data: encoded)
        
        #expect(decoded.metadata?.data == sampleMetadata.data, "Decoded metadata should match the original")
        #expect(decoded.nativeScripts == sampleNativeScripts, "Decoded native scripts should match the original")
        #expect(decoded.plutusV1Script == plutusV1Script, "Decoded Plutus scripts should match the original")
        #expect(decoded.plutusV2Script == plutusV2Script, "Decoded Plutus scripts should match the original")
        #expect(decoded.plutusV3Script == plutusV3Script, "Decoded Plutus scripts should match the original")
    }
    
    @Test("Test Encoding Without Plutus Scripts")
    func testEncodingWithoutPlutusScripts() async throws {
        let alonzoMetadata = AlonzoMetadata(
            metadata: sampleMetadata,
            nativeScripts: sampleNativeScripts,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusV3Script: nil
        )
        
        let encoded = try CBOREncoder().encode(alonzoMetadata)
        
        let decoded = try CBORDecoder().decode(AlonzoMetadata.self, from: encoded)
        
        #expect(decoded.metadata?.data == sampleMetadata.data, "Decoded metadata should match the original")
        #expect(decoded.nativeScripts == sampleNativeScripts, "Decoded native scripts should match the original")
        #expect(decoded.plutusV1Script == nil, "Decoded Plutus scripts should be nil")
    }
    
    @Test("Test Encoding Without Native and Plutus Scripts")
    func testEncodingWithoutNativeAndPlutusScripts() async throws {
        let alonzoMetadata = AlonzoMetadata(
            metadata: sampleMetadata,
            nativeScripts: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusV3Script: nil
        )
        let encoded = try CBOREncoder().encode(alonzoMetadata)
        let decoded = try CBORDecoder().decode(AlonzoMetadata.self, from: encoded)
        
        #expect(decoded.metadata?.data == sampleMetadata.data, "Decoded metadata should match the original")
        #expect(decoded.nativeScripts == nil, "Decoded native scripts should be nil")
        #expect(decoded.plutusV1Script == nil, "Decoded Plutus scripts should be nil")
    }
}


@Suite struct AuxiliaryDataTests {
    let sampleMetadataType = MetadataType.metadata(try! Metadata(validMetadata))
    
    @Test("Test Encoding and Decoding AuxiliaryData")
    func testEncodingDecoding() async throws {
        let auxiliaryData = AuxiliaryData(data: sampleMetadataType)
        let encoded = try auxiliaryData.toCBORData()
        let decoded = try AuxiliaryData.fromCBOR(data: encoded)
        
        #expect(decoded.data == sampleMetadataType, "Decoded auxiliary data should match the original")
    }
}
