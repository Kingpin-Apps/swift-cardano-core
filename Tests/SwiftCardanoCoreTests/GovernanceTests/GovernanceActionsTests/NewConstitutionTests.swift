import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct NewConstitutionTests {
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0, count: 32)),
        govActionIndex: 0
    )
    
    let constitution = Constitution(
        anchor: Anchor(
            anchorUrl: try! Url("https://example.com/constitution"),
            anchorDataHash: AnchorDataHash(payload: Data(repeating: 0, count: 32))
        ),
        scriptHash: ScriptHash(payload: Data(repeating: 0, count: 32))
    )
    
    @Test func testInitialization() async throws {
        let action = NewConstitution(
            id: govActionID,
            constitution: constitution
        )
        
        #expect(NewConstitution.code == .newConstitution)
        #expect(action != nil)
        #expect(action.id == govActionID)
        #expect(action.constitution == constitution)
    }
    
    @Test func testEncoding() async throws {
        let action = NewConstitution(
            id: govActionID,
            constitution: constitution
        )
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(NewConstitution.self, from: cborData)
        
        #expect(action == decoded)
    }
}
