import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct HardForkInitiationActionTests {
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0, count: 32)),
        govActionIndex: 0
    )
    
    let protocolVersion = ProtocolVersion(
        major: 1,
        minor: 2
    )
    
    @Test func testInitialization() async throws {
        let action = HardForkInitiationAction(
            id: govActionID,
            protocolVersion: protocolVersion
        )
        
        #expect(HardForkInitiationAction.code == .hardForkInitiationAction)
        #expect(
            action.id!.transactionID.payload == Data(repeating: 0, count: 32)
        )
        #expect(action.id!.govActionIndex == 0)
        #expect(action.protocolVersion.major == 1)
        #expect(action.protocolVersion.minor == 2)
    }
    
    @Test func testEncoding() async throws {
        let action = HardForkInitiationAction(
            id: govActionID,
            protocolVersion: protocolVersion
        )
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(HardForkInitiationAction.self, from: cborData)
        
        #expect(action == decoded)
    }
}
