import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ShelleyGenesis Tests")
struct ShelleyGenesisTests {
    let filePath = try! getFilePath(
        forResource: shelleyGenesisJSONFilePath.forResource,
        ofType: shelleyGenesisJSONFilePath.ofType,
        inDirectory: shelleyGenesisJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        let shelleyGenesis = try ShelleyGenesis.load(from: filePath!)
        #expect(shelleyGenesis != nil)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("shelleyGenesis.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try ShelleyGenesis.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try ShelleyGenesis.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
