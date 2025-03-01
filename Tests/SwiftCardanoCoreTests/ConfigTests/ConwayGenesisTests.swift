import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ConwayGenesis Tests")
struct ConwayGenesisTests {
    let filePath = try! getFilePath(
        forResource: conwayGenesisJSONFilePath.forResource,
        ofType: conwayGenesisJSONFilePath.ofType,
        inDirectory: conwayGenesisJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        let conwayGenesis = try ConwayGenesis.load(from: filePath!)
        #expect(conwayGenesis != nil)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("conwayGenesis.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try ConwayGenesis.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try ConwayGenesis.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
