import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("AlonzoGenesis Tests")
struct AlonzoGenesisTests {
    let filePath = try! getFilePath(
        forResource: alonzoGenesisJSONFilePath.forResource,
        ofType: alonzoGenesisJSONFilePath.ofType,
        inDirectory: alonzoGenesisJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        _ = try AlonzoGenesis.load(from: filePath!)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("alonzoGenesis.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try AlonzoGenesis.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try AlonzoGenesis.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
