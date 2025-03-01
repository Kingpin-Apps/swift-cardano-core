import Foundation

public struct GenesisParameters: JSONLoadable {
    public let alonzoGenesis: AlonzoGenesis?
    public let byronGenesis: ByronGenesis?
    public let conwayGenesis: ConwayGenesis?
    public let shelleyGenesis: ShelleyGenesis?
    public let era: Era?
    public let activeSlotsCoefficient: Double?
    public let epochLength: Int?
    public let maxKesEvolutions: Int?
    public let maxLovelaceSupply: Int?
    public let networkId: String?
    public let networkMagic: Int?
    public let securityParam: Int?
    public let slotLength: Int?
    public let slotsPerKesPeriod: Int?
    public let systemStart: Date?
    public let updateQuorum: Int?

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
    
    init(nodeConfig: NodeConfig, era: Era = .conway, inDirectory: String? = nil) throws {
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
    
    init(alonzoGenesis: AlonzoGenesis,
         byronGenesis: ByronGenesis,
         conwayGenesis: ConwayGenesis,
         shelleyGenesis: ShelleyGenesis, era: Era = .conway) {
        self.alonzoGenesis = alonzoGenesis
        self.byronGenesis = byronGenesis
        self.conwayGenesis = conwayGenesis
        self.shelleyGenesis = shelleyGenesis
        
        self.era = era
        self.activeSlotsCoefficient = shelleyGenesis.activeSlotsCoeff
        self.epochLength = Int(shelleyGenesis.epochLength)
        self.maxKesEvolutions = Int(shelleyGenesis.maxKESEvolutions)
        self.maxLovelaceSupply = Int(shelleyGenesis.maxLovelaceSupply)
        self.networkId = shelleyGenesis.networkId
        self.networkMagic = Int(shelleyGenesis.networkMagic)
        self.securityParam = Int(shelleyGenesis.securityParam)
        self.slotLength = Int(shelleyGenesis.slotLength)
        self.slotsPerKesPeriod = Int(shelleyGenesis.slotsPerKESPeriod)
        self.systemStart = ISO8601DateFormatter().date(from: shelleyGenesis.systemStart)
        self.updateQuorum = shelleyGenesis.updateQuorum
    }
    
    init(activeSlotsCoefficient: Double,
         epochLength: Int,
         maxKesEvolutions: Int,
         maxLovelaceSupply: Int,
         networkId: String,
         networkMagic: Int,
         securityParam: Int,
         slotLength: Int,
         slotsPerKesPeriod: Int,
         systemStart: Date,
         updateQuorum: Int, era: Era = .conway) {
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
