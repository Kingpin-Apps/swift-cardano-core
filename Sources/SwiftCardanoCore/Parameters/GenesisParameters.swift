import Foundation

public struct GenesisParameters: JSONLoadable {
    public let alonzoGenesis: AlonzoGenesis?
    public let byronGenesis: ByronGenesis?
    public let conwayGenesis: ConwayGenesis?
    public let shelleyGenesis: ShelleyGenesis?
    public let era: Era?
    /// The ledger's `PositiveUnitInterval`, held exactly.
    public let activeSlotsCoefficient: UnitInterval?
    // Widths as in the ledger's ShelleyGenesis.
    public let epochLength: UInt64?
    public let maxKesEvolutions: UInt64?
    public let maxLovelaceSupply: UInt64?
    public let networkId: String?
    public let networkMagic: UInt32?
    public let securityParam: UInt64?
    /// Seconds, to the microsecond.
    public let slotLength: Decimal?
    public let slotsPerKesPeriod: UInt64?
    public let systemStart: Date?
    public let updateQuorum: UInt64?

    enum CodingKeys: String, CodingKey {
        case alonzoGenesis
        case byronGenesis
        case conwayGenesis
        case shelleyGenesis
        case era
        case activeSlotsCoefficient
        case epochLength
        case maxKesEvolutions
        case maxLovelaceSupply
        case networkId
        case networkMagic
        case securityParam
        case slotLength
        case slotsPerKesPeriod
        case systemStart
        case updateQuorum
    }
    
    public init(nodeConfigFilePath: String, era: Era = .conway) throws {
        let nodeConfig = try NodeConfig.load(from: nodeConfigFilePath)
        
        let url = URL(fileURLWithPath: nodeConfigFilePath)
        let pathWithoutFilename = url.deletingLastPathComponent().path
        
        try self.init(
            nodeConfig: nodeConfig,
            inDirectory: pathWithoutFilename
        )
    }
    
    public init(nodeConfig: NodeConfig, era: Era = .conway, inDirectory: String? = nil) throws {
        let alonzoGenesis = try AlonzoGenesis.load(
            from: (inDirectory != nil) ? "\(inDirectory!)/\(nodeConfig.alonzoGenesisFile)" : nodeConfig.alonzoGenesisFile
        )
        let byronGenesis = try ByronGenesis.load(
            from: (inDirectory != nil) ? "\(inDirectory!)/\(nodeConfig.byronGenesisFile)" : nodeConfig.byronGenesisFile
        )
        let conwayGenesis = try ConwayGenesis.load(
            from: (inDirectory != nil) ? "\(inDirectory!)/\(nodeConfig.conwayGenesisFile)" : nodeConfig.conwayGenesisFile
        )
        let shelleyGenesis = try ShelleyGenesis.load(
            from: (inDirectory != nil) ? "\(inDirectory!)/\(nodeConfig.shelleyGenesisFile)" : nodeConfig.shelleyGenesisFile
        )
        
        self.init(
            alonzoGenesis: alonzoGenesis,
            byronGenesis: byronGenesis,
            conwayGenesis: conwayGenesis,
            shelleyGenesis: shelleyGenesis,
            era: era
        )
    }
    
    public init(alonzoGenesis: AlonzoGenesis,
         byronGenesis: ByronGenesis,
         conwayGenesis: ConwayGenesis,
         shelleyGenesis: ShelleyGenesis, era: Era = .conway) {
        self.alonzoGenesis = alonzoGenesis
        self.byronGenesis = byronGenesis
        self.conwayGenesis = conwayGenesis
        self.shelleyGenesis = shelleyGenesis
        
        self.era = era
        self.activeSlotsCoefficient = shelleyGenesis.activeSlotsCoeff
        self.epochLength = shelleyGenesis.epochLength
        self.maxKesEvolutions = shelleyGenesis.maxKESEvolutions
        self.maxLovelaceSupply = shelleyGenesis.maxLovelaceSupply
        self.networkId = shelleyGenesis.networkId
        self.networkMagic = shelleyGenesis.networkMagic
        self.securityParam = shelleyGenesis.securityParam
        self.slotLength = shelleyGenesis.slotLength
        self.slotsPerKesPeriod = shelleyGenesis.slotsPerKESPeriod
        self.systemStart = shelleyGenesis.systemStartDate
        self.updateQuorum = shelleyGenesis.updateQuorum
    }
    
    public init(activeSlotsCoefficient: UnitInterval,
         epochLength: UInt64,
         maxKesEvolutions: UInt64,
         maxLovelaceSupply: UInt64,
         networkId: String,
         networkMagic: UInt32,
         securityParam: UInt64,
         slotLength: Decimal,
         slotsPerKesPeriod: UInt64,
         systemStart: Date,
         updateQuorum: UInt64, era: Era = .conway) {
        self.alonzoGenesis = nil
        self.byronGenesis = nil
        self.conwayGenesis = nil
        self.shelleyGenesis = nil
        
        self.era = era
        self.activeSlotsCoefficient = activeSlotsCoefficient
        self.epochLength = epochLength
        self.maxKesEvolutions = maxKesEvolutions
        self.maxLovelaceSupply = maxLovelaceSupply
        self.networkId = networkId
        self.networkMagic = networkMagic
        self.securityParam = securityParam
        self.slotLength = slotLength
        self.slotsPerKesPeriod = slotsPerKesPeriod
        self.systemStart = systemStart
        self.updateQuorum = updateQuorum
    }
}
