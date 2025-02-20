import Testing
import Network
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct PoolParamsTests {

    let testPoolOperator = try! stakePoolVerificationKey!.poolKeyHash()
    let testVrfKeyHash = try! vrfVerificationKey!.hash()
    let testPledge = 1_000_000
    let testCost = 340_000_000
    let testMargin = UnitInterval(numerator: 3, denominator: 100)  // 3%
    let testRewardAccount =  try! stakeVerificationKey!.rewardAccountHash(network: .mainnet)
    let testPoolOwners = CBORSet(
        Set([
            try! stakeVerificationKey!.hash()
        ])
    )
    let testRelays: [Relay] = [
        .singleHostAddr(SingleHostAddr(port: 3001, ipv4: IPv4Address("192.168.1.1"), ipv6: nil)),
        .singleHostName(SingleHostName(port: 3002, dnsName: "relay.example.com")),
        .multiHostName(MultiHostName(dnsName: "relay1.example.com")),
    ]
    let testPoolMetadata = try! PoolMetadata(
        url: try! Url("https://yourpoollink.com/poolMetaData.json"),
        poolMetadataHash: PoolMetadataHash(
            payload: poolMetadataHash!.hexStringToData
        )
    )

    @Test("Test PoolParams Initialization")
    func testPoolParamsInitialization() async throws {
        let poolParams = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        #expect(poolParams.poolOperator == testPoolOperator)
        #expect(poolParams.vrfKeyHash == testVrfKeyHash)
        #expect(poolParams.pledge == testPledge)
        #expect(poolParams.cost == testCost)
        #expect(poolParams.margin == testMargin)
        #expect(poolParams.rewardAccount == testRewardAccount)
        #expect(poolParams.poolOwners == testPoolOwners)
        #expect(poolParams.relays == testRelays)
        #expect(poolParams.poolMetadata == testPoolMetadata)
    }

    @Test("Test PoolParams CBOR Encoding and Decoding")
    func testPoolParamsCBORSerialization() async throws {
        let poolParams = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        let encodedCBOR = try CBOREncoder().encode(poolParams)
        let decodedPoolParams = try CBORDecoder().decode(PoolParams.self, from: encodedCBOR)

        #expect(decodedPoolParams == poolParams)
    }

    @Test("Test PoolParams Hashing")
    func testPoolParamsHashing() async throws {
        let poolParams1 = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        let poolParams2 = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        var hasher1 = Hasher()
        var hasher2 = Hasher()

        poolParams1.hash(into: &hasher1)
        poolParams2.hash(into: &hasher2)

        #expect(hasher1.finalize() == hasher2.finalize())
    }

    @Test("Test PoolParams Equality")
    func testPoolParamsEquality() async throws {
        let poolParams1 = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        let poolParams2 = PoolParams(
            poolOperator: testPoolOperator,
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        let differentPoolParams = PoolParams(
            poolOperator: PoolKeyHash(payload: Data([0xFF, 0xEE, 0xDD])),
            vrfKeyHash: testVrfKeyHash,
            pledge: testPledge,
            cost: testCost,
            margin: testMargin,
            rewardAccount: testRewardAccount,
            poolOwners: testPoolOwners,
            relays: testRelays,
            poolMetadata: testPoolMetadata,
            id: nil
        )

        #expect(poolParams1 == poolParams2)
        #expect(poolParams1 != differentPoolParams)
    }
}
