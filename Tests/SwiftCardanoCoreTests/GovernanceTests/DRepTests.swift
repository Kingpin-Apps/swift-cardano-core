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
        _ = DRep(credential: credential)
    }
    
    @Test func testId() async throws {
        let drepType: DRepType = .verificationKeyHash(try drepVerificationKey!.hash())
        let drep = DRep(credential: drepType)
        
        let excpectedDrepId = try! drep.id()
        let excpectedDrepHexId = try! drep.idHex()
        
        let cip105 = "drep1kqhhkv66a0egfw7uyz7u8dv7fcvr4ck0c3ad9k9urx3yzhefup0"
        let cip129 = "drep1y2cz77entt4l9p9mmsstmsa4ne8pswhzelz845kchsv6ysgdhay86"
        let drepcip105 = try DRep(from: cip105)
        let drepcip129 = try DRep(from: cip129)
        
        let drepFromHash = try DRep(from: excpectedDrepHexId.hexStringToData, as: .keyHash)
        
        #expect(drepcip105 == drepcip129)
        #expect(drepFromHash == drepcip129)
        
        #expect(try drepcip105.id((.bech32, .cip129)) == cip129)
        #expect(try drepcip129.id((.bech32, .cip105)) == cip105)
        
        #expect(drepId! == excpectedDrepId)
        #expect(drepHexId! == excpectedDrepHexId)
    }
}
