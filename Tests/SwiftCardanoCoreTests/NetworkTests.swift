import PotentCodables
import Testing
@testable import SwiftCardanoCore

@Suite struct NetworkTests {

    @Test func testTestnet() async throws {
        let value = Network.testnet
        
        let networkCBOR = Network.testnet.toCBOR()!
        let fromCBOR = Network.fromCBOR(networkCBOR)
        
        let primitive = value.toPrimitive()
        let fromPrimitive: Network = try Network.fromPrimitive(primitive)
        
        #expect(fromCBOR == value)
        #expect(fromPrimitive == value)
    }

    @Test func testMainnet() async throws {
        let value = Network.mainnet
        
        let networkCBOR = Network.mainnet.toCBOR()!
        let fromCBOR = Network.fromCBOR(networkCBOR)
        
        let primitive = value.toPrimitive()
        let fromPrimitive: Network = try Network.fromPrimitive(primitive)
        
        #expect(fromCBOR == value)
        #expect(fromPrimitive == value)
    }
    
    @Test func testFromPrimitiveFail() async throws {
        #expect(throws: CardanoException.self) {
            let _ = try Network.fromPrimitive(-1)
        }
    }

}
