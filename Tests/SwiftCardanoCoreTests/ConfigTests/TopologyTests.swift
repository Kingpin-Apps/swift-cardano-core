import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("Topology Tests")
struct TopologyTests {
    let filePath = try! getFilePath(
        forResource: topologyJSONFilePath.forResource,
        ofType: topologyJSONFilePath.ofType,
        inDirectory: topologyJSONFilePath.inDirectory
    )
    
    @Test func testInit() async throws {
        let topology = try Topology.load(from: filePath!)
        #expect(topology != nil)
    }
    
    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("topology.json")
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let genesis = try Topology.load(from: filePath!)
        
        try genesis.save(to: tempFileURL.path)
        let loadedGenesis = try Topology.load(from: tempFileURL.path)
        
        #expect(genesis == loadedGenesis)
    }
}
