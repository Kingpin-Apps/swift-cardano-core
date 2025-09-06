import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct InfoActionTests {
    @Test func testInitialization() async throws {
        _ = InfoAction()
        
        #expect(InfoAction.code == .infoAction)
    }
    
    @Test func testEncoding() async throws {
        let action = InfoAction()
        
        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(InfoAction.self, from: cborData)
        
        #expect(action == decoded)
    }
}
