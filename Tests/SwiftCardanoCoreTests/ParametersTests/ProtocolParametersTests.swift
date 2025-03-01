import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ProtocolParameters Tests")
struct ProtocolParametersTests {
    let filePath = try! getFilePath(
        forResource: protocolParametersJSONFilePath.forResource,
        ofType: protocolParametersJSONFilePath.ofType,
        inDirectory: protocolParametersJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        let protocolParameters = try ProtocolParameters.load(from: filePath!)
        #expect(protocolParameters != nil)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("protocolParameters.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let protocolParameters = try ProtocolParameters.load(from: filePath!)
        
        try protocolParameters.save(to: tempFileURL.path)
        let loadedProtocolParameters = try ProtocolParameters.load(from: tempFileURL.path)
        
        #expect(protocolParameters == loadedProtocolParameters)
    }
}
