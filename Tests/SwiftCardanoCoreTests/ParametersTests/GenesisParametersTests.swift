import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct GenesisParametersTests {
    let activeSlotsCoefficient = 1000
    let maxLovelaceSupply = 45_000_000_000
    let networkId = "mainnet"
    let networkMagic = 42
    let epochLength = 21600
    let systemStart = ISO8601DateFormatter().date(from: "2017-09-23T21:44:51Z")!
    let slotsPerKesPeriod = 1_200
    let slotLength = 1
    let maxKESEvolutions = 90
    let securityParam = 2160
    let updateQuorum = 5
    let maxLovelaceSupplyStr = "4500000000000000"
    
    @Test func testInitialization() async throws {
        let genesisParameters = GenesisParameters(
            activeSlotsCoefficient: Double(activeSlotsCoefficient),
            epochLength: epochLength,
            maxKesEvolutions: maxKESEvolutions,
            maxLovelaceSupply: maxLovelaceSupply,
            networkId: networkId,
            networkMagic: networkMagic,
            securityParam: securityParam,
            slotLength: slotLength,
            slotsPerKesPeriod: slotsPerKesPeriod,
            systemStart: systemStart,
            updateQuorum: updateQuorum
        )
        
        #expect(genesisParameters.activeSlotsCoefficient == Double(activeSlotsCoefficient))
        #expect(genesisParameters.epochLength == epochLength)
        #expect(genesisParameters.maxKesEvolutions == maxKESEvolutions)
        #expect(genesisParameters.maxLovelaceSupply == maxLovelaceSupply)
        #expect(genesisParameters.networkId == networkId)
        #expect(genesisParameters.networkMagic == networkMagic)
        #expect(genesisParameters.securityParam == securityParam)
        #expect(genesisParameters.slotLength == slotLength)
        #expect(genesisParameters.slotsPerKesPeriod == slotsPerKesPeriod)
        #expect(genesisParameters.systemStart == systemStart)
        #expect(genesisParameters.updateQuorum == updateQuorum)
    }
    
    @Test func testFromNodeConfigFiles() async throws {
        
        let filePath = try! getFilePath(
            forResource: nodeConfigJSONFilePath.forResource,
            ofType: nodeConfigJSONFilePath.ofType,
            inDirectory: nodeConfigJSONFilePath.inDirectory
        )
        
        let url = URL(fileURLWithPath: filePath!)
        let pathWithoutFilename = url.deletingLastPathComponent().path
        
        let nodeConfig = try NodeConfig.load(from: filePath!)
        let genesisParameters = try GenesisParameters(
            nodeConfig: nodeConfig,
            inDirectory: pathWithoutFilename
        )
        
        #expect(genesisParameters != nil)
    }
    
    @Test func testFromGenesisFiles() async throws {
        
        let alonzoGenesisfilePath = try! getFilePath(
            forResource: alonzoGenesisJSONFilePath.forResource,
            ofType: alonzoGenesisJSONFilePath.ofType,
            inDirectory: alonzoGenesisJSONFilePath.inDirectory
        )
        let alonzoGenesis = try AlonzoGenesis.load(from: alonzoGenesisfilePath!)
        
        let byronGenesisfilePath = try! getFilePath(
            forResource: byronGenesisJSONFilePath.forResource,
            ofType: byronGenesisJSONFilePath.ofType,
            inDirectory: byronGenesisJSONFilePath.inDirectory
        )
        let byronGenesis = try ByronGenesis.load(from: byronGenesisfilePath!)
        
        let conwayGenesisfilePath = try! getFilePath(
            forResource: conwayGenesisJSONFilePath.forResource,
            ofType: conwayGenesisJSONFilePath.ofType,
            inDirectory: conwayGenesisJSONFilePath.inDirectory
        )
        let conwayGenesis = try ConwayGenesis.load(from: conwayGenesisfilePath!)
        
        let shelleyGenesisfilePath = try! getFilePath(
            forResource: shelleyGenesisJSONFilePath.forResource,
            ofType: shelleyGenesisJSONFilePath.ofType,
            inDirectory: shelleyGenesisJSONFilePath.inDirectory
        )
        let shelleyGenesis = try ShelleyGenesis.load(from: shelleyGenesisfilePath!)
        
        let genesisParameters = GenesisParameters(
            alonzoGenesis: alonzoGenesis,
            byronGenesis: byronGenesis,
            conwayGenesis: conwayGenesis,
            shelleyGenesis: shelleyGenesis
        )
        
        #expect(genesisParameters != nil)
    }
        
        
}
