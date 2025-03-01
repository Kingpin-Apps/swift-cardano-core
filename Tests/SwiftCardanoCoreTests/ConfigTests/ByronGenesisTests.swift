import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ByronGenesis Tests")
struct ByronGenesisTests {
    let filePath = try! getFilePath(
        forResource: byronGenesisJSONFilePath.forResource,
        ofType: byronGenesisJSONFilePath.ofType,
        inDirectory: byronGenesisJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        let byronGenesis = try ByronGenesis.load(from: filePath!)
        #expect(byronGenesis != nil)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("byronGenesis.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try ByronGenesis.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try ByronGenesis.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
