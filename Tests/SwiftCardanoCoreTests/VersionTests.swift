import Testing
import Foundation
import Version
@testable import SwiftCardanoCore

@Suite struct VersionTests {
    
    @Test func testVersion() async throws {
        let testVersionValue = SwiftCardanoCore.version
        
        #expect(testVersionValue != nil)
    }
}
