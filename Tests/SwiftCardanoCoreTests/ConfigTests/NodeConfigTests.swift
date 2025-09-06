import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("NodeConfig Tests")
struct NodeConfigTests {
    let filePath = try! getFilePath(
        forResource: nodeConfigJSONFilePath.forResource,
        ofType: nodeConfigJSONFilePath.ofType,
        inDirectory: nodeConfigJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        _ = try NodeConfig.load(from: filePath!)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("nodeConfig.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try NodeConfig.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try NodeConfig.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
