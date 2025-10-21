import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct PoolOperatorTests {

    let validPoolId = "pool1m5947rydk4n0ywe6ctlav0ztt632lcwjef7fsy93sflz7ctcx6z"
    let invalidPoolId = "invalidPoolId"

    @Test("Test Valid PoolId Initialization")
    func testValidPoolIdInitialization() async throws {
        let poolId = try PoolOperator(from: validPoolId)
        #expect(try poolId.id() == validPoolId)
    }

    @Test("Test Invalid PoolId Initialization")
    func testInvalidPoolIdInitialization() async throws {
        #expect(throws: Bech32.DecodingError.invalidCase.self) {
            _ = try PoolOperator(from: invalidPoolId)
        }
    }

    @Test("Test PoolId Bech32 Decoding")
    func testPoolIdBech32Decoding() async throws {
        let poolId = try PoolOperator(from: validPoolId)
        let decodedHex = try poolId.id(.hex)
        #expect(!decodedHex.isEmpty)
    }

    @Test("Test PoolId CBOR Encoding and Decoding")
    func testPoolIdCBORSerialization() async throws {
        let poolId = try PoolOperator(from: validPoolId)
        let encodedCBOR = try CBOREncoder().encode(poolId)
        let decodedPoolId = try CBORDecoder().decode(PoolOperator.self, from: encodedCBOR)

        #expect(decodedPoolId == poolId)
    }

    @Test("Test PoolId Loading")
    func testLoading() async throws {
        #expect(poolId == poolIdHex)
    }

    @Test("Test PoolId Hashing")
    func testPoolIdHashing() async throws {
        let poolId1 = try PoolOperator(from: validPoolId)
        let poolId2 = try PoolOperator(from: validPoolId)

        var hasher1 = Hasher()
        var hasher2 = Hasher()

        poolId1.hash(into: &hasher1)
        poolId2.hash(into: &hasher2)

        #expect(hasher1.finalize() == hasher2.finalize())
    }
}
