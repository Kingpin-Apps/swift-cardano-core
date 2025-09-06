import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct NoConfidenceTests {
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0, count: 32)),
        govActionIndex: 0
    )
    
    @Test func testInitialization() async throws {
        let action = NoConfidence(
            id: govActionID
        )
        
        #expect(NoConfidence.code == .noConfidence)
        #expect(action.id == govActionID)
    }
    
    @Test func testEncoding() async throws {
        let action = NoConfidence(
            id: govActionID
        )
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(NoConfidence.self, from: cborData)
        
        #expect(action == decoded)
    }
}
