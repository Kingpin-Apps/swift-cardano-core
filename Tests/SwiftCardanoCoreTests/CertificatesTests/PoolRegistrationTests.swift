import Testing
import Foundation
import PotentCBOR
import FractionNumber
@testable import SwiftCardanoCore

@Suite struct PoolRegistrationTests {
    let poolParams = PoolParams(
        poolOperator: try! stakePoolVerificationKey!.poolKeyHash(),
        vrfKeyHash: try! vrfVerificationKey!.hash(),
        pledge: 100000000,
        cost: 340000000,
        margin: UnitInterval(numerator: 1, denominator: 100),
        rewardAccount: try! stakeVerificationKey!.rewardAccountHash(network: .mainnet),
        poolOwners: .orderedSet(
            try! OrderedSet(
                Set([
                    try! stakeVerificationKey!.hash()
                ])
            )
        ),
        relays: [
            .singleHostName(
                SingleHostName(port: 6000, dnsName: "relay.yourpoollink.com")
            )
        ],
        poolMetadata: try! PoolMetadata(
            url: try! Url("https://yourpoollink.com/poolMetaData.json"),
            poolMetadataHash: PoolMetadataHash(
                payload: poolMetadataHash!.hexStringToData
            )
        ),
        id: nil
    )
    
    @Test func testInitialization() async throws {
        
        let poolRegistration = PoolRegistration(poolParams: poolParams)
        
        #expect(PoolRegistration.CODE.rawValue == 3)
        #expect(poolRegistration.poolParams == poolParams)
    }
    
    @Test func testJSON() async throws {
        let cert = poolRegistrationCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try PoolRegistration.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = poolRegistrationCertificate?.payload.toHex
        
        let cert = PoolRegistration(poolParams: poolParams)
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(PoolRegistration.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
