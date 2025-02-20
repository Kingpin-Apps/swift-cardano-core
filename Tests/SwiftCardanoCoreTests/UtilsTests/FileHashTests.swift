import Testing
import Network
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct FileHashTests {
    @Test func testInitialization() async throws {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        let fileHash = try FileHash.load(from: filePath!)
        
        #expect(try! fileHash.hash() == poolMetadataHash!)
    }
}
