import Testing
import PotentCBOR
import PotentCodables
@testable import SwiftCardanoCore

@Suite struct EraTests {
    @Test("Test Era Initialization and Properties", arguments: Era.allCases)
    func testEraInitialization(_ era: Era) async throws {
        #expect(era == Era(from: era.description))
    }
    
    @Test("Test Era fromEpoch")
    func testFromEpoch() async throws {
        #expect(
            .byron == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 0...207)))
        )
        #expect(
            .shelley == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 208...235)))
        )
        #expect(
            .allegra == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 236...250)))
        )
        #expect(
            .mary == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 251...289)))
        )
        #expect(
            .alonzo == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 290...364)))
        )
        #expect(
            .babbage == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 365...506)))
        )
        #expect(
            .conway == Era.fromEpoch(epoch: EpochNumber(Int.random(in: 507...595)))
        )
    }
    
    @Test("Test Era CBOR Encoding and Decoding")
    func testEraCBORSerialization() async throws {
        let era = Era.allegra
        
        let encodedCBOR = try CBOREncoder().encode(era)
        let decodedEra = try CBORDecoder().decode(Era.self, from: encodedCBOR)
        
        #expect(decodedEra == era)
    }
}
