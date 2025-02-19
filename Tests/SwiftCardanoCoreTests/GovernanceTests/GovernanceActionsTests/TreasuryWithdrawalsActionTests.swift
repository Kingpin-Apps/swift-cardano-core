import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct TreasuryWithdrawalsActionTests {
    let withdrawals = [
        RewardAccount(0..<32): Coin(2000000)
    ]
    let policyHash = PolicyHash(
        payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE)
    )
    
    @Test func testInitialization() async throws {
        let action = TreasuryWithdrawalsAction(
            withdrawals: withdrawals,
            policyHash: policyHash
        )
        
        #expect(TreasuryWithdrawalsAction.code == .treasuryWithdrawalsAction)
        #expect(action != nil)
        #expect(action.withdrawals == withdrawals)
        #expect(action.policyHash == policyHash)
    }
    
    @Test func testEncoding() async throws {
        let action = TreasuryWithdrawalsAction(
            withdrawals: withdrawals,
            policyHash: policyHash
        )
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(TreasuryWithdrawalsAction.self, from: cborData)
        
        #expect(action == decoded)
    }
}
