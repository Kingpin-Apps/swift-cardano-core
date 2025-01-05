import Testing
import Foundation

import PotentCBOR
@testable import SwiftCardanoCore
    
func testToCBOR<T: ConstrainedBytes>(for type: T.Type, payload: Data) {
    do {
        let keyHash = try T(payload: payload)
        guard let cborData = keyHash.toCBOR() else {
            Issue.record("Failed to encode \(T.self) to CBOR")
            return
        }
        print("CBOR Data: \(cborData)")
        #expect(cborData != nil, "CBOR data should not be nil")
    } catch {
        Issue.record("Error: \(error)")
    }
}

func testFromCBOR<T: ConstrainedBytes>(for type: T.Type, payload: Data) {
    do {
        let keyHash = try T(payload: payload)
        guard let cborData = keyHash.toCBOR() else {
            Issue.record("Failed to encode \(T.self) to CBOR")
            return
        }
        guard let decodedKeyHash = T.fromCBOR(cborData) else {
            Issue.record("Failed to decode \(T.self) from CBOR")
            return
        }
        #expect(
            decodedKeyHash.payload == keyHash.payload,
            "Decoded payload should match original payload"
        )
    } catch {
        Issue.record("Error: \(error)")
    }
}

func testInvalidSizePayload<T: ConstrainedBytes>(for type: T.Type, payload: Data) {
    #expect(throws: CardanoException.self) {
        let _ = try T(payload: payload)
    }
}

func testValidSizePayload<T: ConstrainedBytes>(for type: T.Type, payload: Data, size: Int) {
    do {
        let keyHash = try T(payload: payload)
        #expect(keyHash.payload.count == size, "Payload size should be \(size)")
    } catch {
        Issue.record("Error: \(error)")
    }
}


@Suite struct VerificationKeyHashTests {
    
    @Test func testVerificationKeyHashToCBOR() async throws {
        testToCBOR(for: VerificationKeyHash.self, payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
    }
    
    @Test func testVerificationKeyHashFromCBOR() async throws {
        testFromCBOR(for: VerificationKeyHash.self, payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
    }
    
    @Test func testVerificationKeyHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE - 1)
        testInvalidSizePayload(for: VerificationKeyHash.self, payload: invalidPayload)
    }
    
    @Test func testVerificationKeyHashValidSizePayload() async throws {
        testValidSizePayload(for: VerificationKeyHash.self, payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE), size: VERIFICATION_KEY_HASH_SIZE)
    }
}

@Suite class ScriptHashTests {
    
    @Test func testScriptHashToCBOR() async throws {
        testToCBOR(for: ScriptHash.self, payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
    }
    
    @Test func testScriptHashFromCBOR() async throws {
        testFromCBOR(for: ScriptHash.self, payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
    }
    
    @Test func testScriptHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: SCRIPT_HASH_SIZE - 1)
        testInvalidSizePayload(for: ScriptHash.self, payload: invalidPayload)
    }
    
    @Test func testScriptHashValidSizePayload() async throws {
        testValidSizePayload(for: ScriptHash.self, payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE), size: SCRIPT_HASH_SIZE)
    }
}

@Suite class ScriptDataHashTests {
    
    @Test func testScriptDataHashToCBOR() async throws {
        testToCBOR(for: ScriptDataHash.self, payload: Data(repeating: 0, count: SCRIPT_DATA_HASH_SIZE))
    }
    
    @Test func testScriptDataHashFromCBOR() async throws {
        testFromCBOR(for: ScriptDataHash.self, payload: Data(repeating: 0, count: SCRIPT_DATA_HASH_SIZE))
    }
    
    @Test func testScriptDataHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: SCRIPT_DATA_HASH_SIZE - 1)
        testInvalidSizePayload(for: ScriptDataHash.self, payload: invalidPayload)
    }
    
    @Test func testScriptDataHashValidSizePayload() async throws {
        testValidSizePayload(for: ScriptDataHash.self, payload: Data(repeating: 0, count: SCRIPT_DATA_HASH_SIZE), size: SCRIPT_DATA_HASH_SIZE)
    }
}

@Suite class TransactionIdTests {
    
    @Test func testTransactionIdToCBOR() async throws {
        testToCBOR(for: TransactionId.self, payload: Data(repeating: 0, count: TRANSACTION_HASH_SIZE))
    }
    
    @Test func testTransactionIdFromCBOR() async throws {
        testFromCBOR(for: TransactionId.self, payload: Data(repeating: 0, count: TRANSACTION_HASH_SIZE))
    }
    
    @Test func testTransactionIdInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: TRANSACTION_HASH_SIZE - 1)
        testInvalidSizePayload(for: TransactionId.self, payload: invalidPayload)
    }
    
    @Test func testTransactionIdValidSizePayload() async throws {
        testValidSizePayload(for: TransactionId.self, payload: Data(repeating: 0, count: TRANSACTION_HASH_SIZE), size: TRANSACTION_HASH_SIZE)
    }
}

@Suite class DatumHashTests {
    
    @Test func testDatumHashToCBOR() async throws {
        testToCBOR(for: DatumHash.self, payload: Data(repeating: 0, count: DATUM_HASH_SIZE))
    }
    
    @Test func testDatumHashFromCBOR() async throws {
        testFromCBOR(for: DatumHash.self, payload: Data(repeating: 0, count: DATUM_HASH_SIZE))
    }
    
    @Test func testDatumHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: DATUM_HASH_SIZE - 1)
        testInvalidSizePayload(for: DatumHash.self, payload: invalidPayload)
    }
    
    @Test func testDatumHashValidSizePayload() async throws {
        testValidSizePayload(for: DatumHash.self, payload: Data(repeating: 0, count: DATUM_HASH_SIZE), size: DATUM_HASH_SIZE)
    }
}

@Suite class AuxiliaryDataHashTests {
    
    @Test func testAuxiliaryDataHashToCBOR() async throws {
        testToCBOR(for: AuxiliaryDataHash.self, payload: Data(repeating: 0, count: AUXILIARY_DATA_HASH_SIZE))
    }
    
    @Test func testAuxiliaryDataHashFromCBOR() async throws {
        testFromCBOR(for: AuxiliaryDataHash.self, payload: Data(repeating: 0, count: AUXILIARY_DATA_HASH_SIZE))
    }
    
    @Test func testAuxiliaryDataHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: AUXILIARY_DATA_HASH_SIZE - 1)
        testInvalidSizePayload(for: AuxiliaryDataHash.self, payload: invalidPayload)
    }
    
    @Test func testAuxiliaryDataHashSizePayload() async throws {
        testValidSizePayload(for: AuxiliaryDataHash.self, payload: Data(repeating: 0, count: AUXILIARY_DATA_HASH_SIZE), size: AUXILIARY_DATA_HASH_SIZE)
    }
}

@Suite class PoolKeyHashTests {
    
    @Test func testPoolKeyHashToCBOR() async throws {
        testToCBOR(for: PoolKeyHash.self, payload: Data(repeating: 0, count: POOL_KEY_HASH_SIZE))
    }
    
    @Test func testPoolKeyHashFromCBOR() async throws {
        testFromCBOR(for: PoolKeyHash.self, payload: Data(repeating: 0, count: POOL_KEY_HASH_SIZE))
    }
    
    @Test func testPoolKeyHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: POOL_KEY_HASH_SIZE - 1)
        testInvalidSizePayload(for: PoolKeyHash.self, payload: invalidPayload)
    }
    
    @Test func testPoolKeyHashSizePayload() async throws {
        testValidSizePayload(for: PoolKeyHash.self, payload: Data(repeating: 0, count: POOL_KEY_HASH_SIZE), size: POOL_KEY_HASH_SIZE)
    }
}

@Suite class PoolMetadataHashTests {
    
    @Test func testPoolMetadataHashToCBOR() async throws {
        testToCBOR(for: PoolMetadataHash.self, payload: Data(repeating: 0, count: POOL_METADATA_HASH_SIZE))
    }
    
    @Test func testPoolMetadataHashFromCBOR() async throws {
        testFromCBOR(for: PoolMetadataHash.self, payload: Data(repeating: 0, count: POOL_METADATA_HASH_SIZE))
    }
    
    @Test func testPoolMetadataHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: POOL_METADATA_HASH_SIZE - 1)
        testInvalidSizePayload(for: PoolMetadataHash.self, payload: invalidPayload)
    }
    
    @Test func testPoolMetadataHashSizePayload() async throws {
        testValidSizePayload(for: PoolMetadataHash.self, payload: Data(repeating: 0, count: POOL_METADATA_HASH_SIZE), size: POOL_METADATA_HASH_SIZE)
    }
}

@Suite class VrfKeyHashTests {
    
    @Test func testVrfKeyHashToCBOR() async throws {
        testToCBOR(for: VrfKeyHash.self, payload: Data(repeating: 0, count: VRF_KEY_HASH_SIZE))
    }
    
    @Test func testVrfKeyHashFromCBOR() async throws {
        testFromCBOR(for: VrfKeyHash.self, payload: Data(repeating: 0, count: VRF_KEY_HASH_SIZE))
    }
    
    @Test func testVrfKeyHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: VRF_KEY_HASH_SIZE - 1)
        testInvalidSizePayload(for: VrfKeyHash.self, payload: invalidPayload)
    }
    
    @Test func testVrfKeyHashSizePayload() async throws {
        testValidSizePayload(for: VrfKeyHash.self, payload: Data(repeating: 0, count: VRF_KEY_HASH_SIZE), size: VRF_KEY_HASH_SIZE)
    }
}

@Suite class RewardAccountHashTests {
    
    @Test func testRewardAccountHashToCBOR() async throws {
        testToCBOR(for: RewardAccountHash.self, payload: Data(repeating: 0, count: REWARD_ACCOUNT_HASH_SIZE))
    }
    
    @Test func testRewardAccountHashFromCBOR() async throws {
        testFromCBOR(for: RewardAccountHash.self, payload: Data(repeating: 0, count: REWARD_ACCOUNT_HASH_SIZE))
    }
    
    @Test func testRewardAccountHashInvalidSizePayload() async throws {
        let invalidPayload = Data(repeating: 0, count: REWARD_ACCOUNT_HASH_SIZE - 1)
        testInvalidSizePayload(for: RewardAccountHash.self, payload: invalidPayload)
    }
    
    @Test func testRewardAccountHashSizePayload() async throws {
        testValidSizePayload(for: RewardAccountHash.self, payload: Data(repeating: 0, count: REWARD_ACCOUNT_HASH_SIZE), size: REWARD_ACCOUNT_HASH_SIZE)
    }
}
