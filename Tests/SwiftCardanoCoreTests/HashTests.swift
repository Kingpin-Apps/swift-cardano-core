import Testing
import Foundation

import PotentCBOR
@testable import SwiftCardanoCore

let hashTestsArguments: Zip2Sequence<[any ConstrainedBytes.Type], [Int]> = zip([
    VerificationKeyHash.self,
    ScriptHash.self,
    ScriptDataHash.self,
    TransactionId.self,
    DatumHash.self,
    AuxiliaryDataHash.self,
    PoolKeyHash.self,
    PoolMetadataHash.self,
    VrfKeyHash.self,
    RewardAccountHash.self,
    GenesisHash.self,
    GenesisDelegateHash.self,
    AddressKeyHash.self,
    AnchorDataHash.self
],[
    VERIFICATION_KEY_HASH_SIZE,
    SCRIPT_HASH_SIZE,
    SCRIPT_DATA_HASH_SIZE,
    TRANSACTION_HASH_SIZE,
    DATUM_HASH_SIZE,
    AUXILIARY_DATA_HASH_SIZE,
    POOL_KEY_HASH_SIZE,
    POOL_METADATA_HASH_SIZE,
    VRF_KEY_HASH_SIZE,
    REWARD_ACCOUNT_HASH_SIZE,
    GENESIS_HASH_SIZE,
    GENESIS_DELEGATE_HASH_SIZE,
    ADDRESS_KEY_HASH_SIZE,
    ANCHOR_DATA_HASH_SIZE
])

@Suite struct HashTests {
    @Test("Test CBOR Encoding", arguments: hashTestsArguments)
    func testToCBOR(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let payload = Data(repeating: 0, count: size)
        let keyHash = try type.init(payload: payload)
        let cborData = try CBOREncoder().encode(keyHash)
        #expect(cborData.count > 0, "CBOR data should not be nil")
    }
    
    @Test("Test CBOR Decoding", arguments: hashTestsArguments)
    func testFromCBOR(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let payload = Data(repeating: 0, count: size)
        let keyHash = try type.init(payload: payload)
        let cborData = try CBOREncoder().encode(keyHash)
        
        let decodedKeyHash = try CBORDecoder().decode(type, from: cborData)
        
        #expect(
            decodedKeyHash.payload == keyHash.payload,
            "Decoded payload should match original payload"
        )
    }
    
    @Test("Test Invalid Payload", arguments: hashTestsArguments)
    func testInvalidSizePayload(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        let invalidPayload = Data(repeating: 0, count: size - 1)
        #expect(throws: Never.self) {
            let _ = try type.init(payload: invalidPayload)
        }
    }
    
    @Test("Test Valid Payload", arguments: hashTestsArguments)
    func testValidSizePayload(_ type: any ConstrainedBytes.Type, size: Int) async throws {
        do {
            let payload = Data(repeating: 0, count: size)
            let keyHash = try type.init(payload: payload)
            #expect(keyHash.payload.count == size, "Payload size should be \(size)")
        } catch {
            Issue.record("Error: \(error)")
        }
    }
    
}
