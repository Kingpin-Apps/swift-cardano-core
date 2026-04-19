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
    
    @Test("Test Era init from wire tag - valid tags", arguments: zip(0..<Era.allCases.count, Era.allCases))
    func testInitFromWireTagValid(index: Int, expected: Era) async throws {
        let era = Era(from: UInt16(index))
        #expect(era == expected)
    }

    @Test("Test Era init from wire tag - out of bounds returns nil")
    func testInitFromWireTagOutOfBounds() async throws {
        #expect(Era(from: UInt16(Era.allCases.count)) == nil)
        #expect(Era(from: UInt16.max) == nil)
    }

    @Test("Test Era toWireTag", arguments: zip(Era.allCases, 0..<Era.allCases.count))
    func testToWireTag(era: Era, expectedIndex: Int) async throws {
        let tag = try era.toWireTag()
        #expect(tag == UInt16(expectedIndex))
    }

    @Test("Test Era wire tag round-trip", arguments: Era.allCases)
    func testWireTagRoundTrip(era: Era) async throws {
        let tag = try era.toWireTag()
        let decoded = Era(from: tag)
        #expect(decoded == era)
    }

    @Test("Test Era CBOR Encoding and Decoding")
    func testEraCBORSerialization() async throws {
        let era = Era.allegra
        
        let encodedCBOR = try CBOREncoder().encode(era)
        let decodedEra = try CBORDecoder().decode(Era.self, from: encodedCBOR)
        
        #expect(decodedEra == era)
    }
}
