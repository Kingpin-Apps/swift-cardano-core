import Testing
import Foundation
import CBORCodable
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

    /// Recent cardano-node releases drop fields such as `EnableP2P`, and the set
    /// of tracing flags shifts between versions. Decoding must tolerate a config
    /// that only carries the genesis-file references.
    @Test func testForgivingDecodeWithMissingFields() async throws {
        let json = """
        {
            "AlonzoGenesisFile": "alonzo-genesis.json",
            "ByronGenesisFile": "byron-genesis.json",
            "ConwayGenesisFile": "conway-genesis.json",
            "ShelleyGenesisFile": "shelley-genesis.json",
            "Protocol": "Cardano",
            "SomeFieldAddedInAFutureRelease": true
        }
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nodeConfig-minimal-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try json.write(to: tempURL, atomically: true, encoding: .utf8)

        let config = try NodeConfig.load(from: tempURL.path)
        #expect(config.shelleyGenesisFile == "shelley-genesis.json")
        #expect(config.byronGenesisFile == "byron-genesis.json")
        #expect(config.enableP2P == nil)
        #expect(config.traceForge == nil)
    }

    @Test func testDecodeWithEmptyLoggingOptions() async throws {
        // The current preview/preprod node configs ship `"options": {}` — the
        // legacy iohk-monitoring `mapBackends`/`mapSubtrace` fields are absent.
        // Decoding must tolerate that (regression: it threw keyNotFound).
        let json = """
        {
            "AlonzoGenesisFile": "alonzo-genesis.json",
            "ByronGenesisFile": "byron-genesis.json",
            "ConwayGenesisFile": "conway-genesis.json",
            "ShelleyGenesisFile": "shelley-genesis.json",
            "Protocol": "Cardano",
            "options": {}
        }
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nodeConfig-empty-options-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try json.write(to: tempURL, atomically: true, encoding: .utf8)

        let config = try NodeConfig.load(from: tempURL.path)
        #expect(config.shelleyGenesisFile == "shelley-genesis.json")
        #expect(config.options != nil)
        #expect(config.options?.mapBackends == nil)
        #expect(config.options?.mapSubtrace == nil)
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
