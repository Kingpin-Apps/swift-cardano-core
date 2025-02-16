import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct DRepTests {
    @Test("Test Initialization", arguments: [
        DRepType.verificationKeyHash(try! drepVerificationKey!.hash()),
        .scriptHash(ScriptHash(payload: scriptHash!.hexStringToData)),
        .alwaysAbstain,
        .alwaysNoConfidence
    ])
    func testInitialization(credential: DRepType) async throws {
        let drep = DRep(credential: credential)
        
        #expect(drep != nil)
    }
    
    @Test func testId() async throws {
        let drepType: DRepType = .verificationKeyHash(try drepVerificationKey!.hash())
        let drep = DRep(credential: drepType)
        
        let excpectedDrepId = try! drep.id
        let excpectedDrepHexId = drep.idHex
        
        #expect(drepId! == excpectedDrepId)
        #expect(drepHexId! == excpectedDrepHexId)
    }
}
