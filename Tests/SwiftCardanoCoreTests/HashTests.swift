import Testing
import Foundation

import PotentCBOR
@testable import SwiftCardanoCore

let arguments = zip([
    VerificationKeyHash.self,
    ScriptHash.self,
    ScriptDataHash.self,
    TransactionId.self,
    DatumHash.self,
    AuxiliaryDataHash.self,
    PoolKeyHash.self,
    PoolMetadataHash.self,
    VrfKeyHash.self,
    RewardAccountHash.self
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
    REWARD_ACCOUNT_HASH_SIZE
])

@Suite struct HashTests {
    @Test("Test CBOR Encoding", arguments: arguments)
    func testToCBOR(_ type: ConstrainedBytes.Type, size: Int) async throws {
        do {
            let payload = Data(repeating: 0, count: size)
            let keyHash = try type.init(payload: payload)
            let cborData = try keyHash.toCBOR()
            print("CBOR Data: \(cborData)")
            #expect(cborData != nil, "CBOR data should not be nil")
        } catch {
            Issue.record("Error: \(error)")
        }
    }
    
    @Test("Test CBOR Decoding", arguments: arguments)
    func testFromCBOR(_ type: ConstrainedBytes.Type, size: Int) async throws {
        do {
            let payload = Data(repeating: 0, count: size)
            let keyHash = try type.init(payload: payload)
            let cborData = try keyHash.toCBOR()
            let decodedKeyHash: ConstrainedBytes
            
            if type == VerificationKeyHash.self {
                decodedKeyHash = try VerificationKeyHash.fromCBOR(cborData)!
            } else if type == ScriptHash.self {
                decodedKeyHash = try ScriptHash.fromCBOR(cborData)!
            } else if type == ScriptDataHash.self {
                decodedKeyHash = try ScriptDataHash.fromCBOR(cborData)!
            } else if type == TransactionId.self {
                decodedKeyHash = try TransactionId.fromCBOR(cborData)!
            } else if type == DatumHash.self {
                decodedKeyHash = try DatumHash.fromCBOR(cborData)!
            } else if type == AuxiliaryDataHash.self {
                decodedKeyHash = try AuxiliaryDataHash.fromCBOR(cborData)!
            } else if type == PoolKeyHash.self {
                decodedKeyHash = try PoolKeyHash.fromCBOR(cborData)!
            } else if type == PoolMetadataHash.self {
                decodedKeyHash = try PoolMetadataHash.fromCBOR(cborData)!
            } else if type == VrfKeyHash.self {
                decodedKeyHash = try VrfKeyHash.fromCBOR(cborData)!
            } else if type == RewardAccountHash.self {
                decodedKeyHash = try RewardAccountHash.fromCBOR(cborData)!
            } else {
                Issue.record("Unknown type: \(type)")
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
    
    @Test("Test Invalid Payload", arguments: arguments)
    func testInvalidSizePayload(_ type: ConstrainedBytes.Type, size: Int) async throws {
        let invalidPayload = Data(repeating: 0, count: size - 1)
        #expect(throws: CardanoException.self) {
            let _ = try type.init(payload: invalidPayload)
        }
    }
    
    @Test("Test Valid Payload", arguments: arguments)
    func testValidSizePayload(_ type: ConstrainedBytes.Type, size: Int) async throws {
        do {
            let payload = Data(repeating: 0, count: size)
            let keyHash = try type.init(payload: payload)
            #expect(keyHash.payload.count == size, "Payload size should be \(size)")
        } catch {
            Issue.record("Error: \(error)")
        }
    }
    
}
