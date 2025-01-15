import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct NetworkTests {

    @Test("Test network", arguments: Network.allCases)
    func testNetwork(_ network: Network) async throws {
        let networkCBOR = try CBOREncoder().encode(network)
        
        let fromCBOR = try CBORDecoder().decode(Network.self, from: networkCBOR)
        
        #expect(fromCBOR == network)
    }
    
    @Test func testFromPrimitiveFail() async throws {
        let networkCBOR = Data([0x03])
        #expect(throws: CardanoCoreError.self) {
            let _ = try CBORDecoder().decode(Network.self, from: networkCBOR)
        }
    }

}
