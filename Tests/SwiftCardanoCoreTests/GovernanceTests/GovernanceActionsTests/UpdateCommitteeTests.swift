import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct UpdateCommitteeTests {
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0, count: 32)),
        govActionIndex: 0
    )
    
    let coldCredentials = Set<CommitteeColdCredential>()
    let credentialEpochs = [
        CommitteeColdCredential(credential:
                .verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: 32)))): UInt64(0)
    ]
    let interval = UnitInterval(numerator: 1, denominator: 2)
    
    @Test func testInitialization() async throws {
        let action = UpdateCommittee(
            id: govActionID,
            coldCredentials: coldCredentials,
            credentialEpochs: credentialEpochs,
            interval: interval
        )
        
        #expect(UpdateCommittee.code == .updateCommittee)
        #expect(
            action.id!.transactionID.payload == Data(repeating: 0, count: 32)
        )
        #expect(action.id!.govActionIndex == 0)
        #expect(action.coldCredentials == coldCredentials)
        #expect(action.credentialEpochs == credentialEpochs)
        #expect(action.interval == interval)
    }
    
    @Test func testEncoding() async throws {
        let action = UpdateCommittee(
            id: govActionID,
            coldCredentials: coldCredentials,
            credentialEpochs: credentialEpochs,
            interval: interval
        )
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(UpdateCommittee.self, from: cborData)
        
        #expect(action == decoded)
    }
}
