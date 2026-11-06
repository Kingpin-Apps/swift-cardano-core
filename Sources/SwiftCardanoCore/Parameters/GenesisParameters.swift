import Foundation

/// The genesis files of a network and the Shelley genesis values most often needed.
public struct GenesisParameters: JSONLoadable {
    /// The Alonzo genesis, when it was loaded.
    public let alonzoGenesis: AlonzoGenesis?
    /// The Byron genesis, when it was loaded.
    public let byronGenesis: ByronGenesis?
    /// The Conway genesis, when it was loaded.
    public let conwayGenesis: ConwayGenesis?
    /// The Shelley genesis, when it was loaded.
    public let shelleyGenesis: ShelleyGenesis?
    /// The era these parameters are for.
    public let era: Era?
    /// The ledger's `PositiveUnitInterval`, held exactly.
    public let activeSlotsCoefficient: UnitInterval?
    // Widths as in the ledger's ShelleyGenesis.
    /// The Shelley genesis `epochLength`, in slots.
    public let epochLength: UInt64?
    /// The Shelley genesis `maxKESEvolutions`.
    public let maxKesEvolutions: UInt64?
    /// The Shelley genesis `maxLovelaceSupply`, in lovelace.
    public let maxLovelaceSupply: UInt64?
    /// The Shelley genesis `networkId`: `"Mainnet"` or `"Testnet"`.
    public let networkId: String?
    /// The Shelley genesis `networkMagic`.
    public let networkMagic: UInt32?
    /// The Shelley genesis `securityParam`.
    public let securityParam: UInt64?
    /// Seconds, to the microsecond.
    public let slotLength: Decimal?
    /// The Shelley genesis `slotsPerKESPeriod`.
    public let slotsPerKesPeriod: UInt64?
    /// The Shelley genesis `systemStart`, or `nil` when it is not a valid time.
    public let systemStart: Date?
    /// The Shelley genesis `updateQuorum`.
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
    
    /// Loads a node config and the four genesis files it names, resolved
    /// against the config file's directory.
    /// - Parameters:
    ///   - nodeConfigFilePath: The path to the node config file.
    ///   - era: The era.
    /// - Throws: When the config or a genesis file cannot be read or decoded.
    public init(nodeConfigFilePath: String, era: Era = .conway) throws {
        let nodeConfig = try NodeConfig.load(from: nodeConfigFilePath)
        
        let url = URL(fileURLWithPath: nodeConfigFilePath)
        let pathWithoutFilename = url.deletingLastPathComponent().path
        
        try self.init(
            nodeConfig: nodeConfig,
            era: era,
            inDirectory: pathWithoutFilename
        )
    }
    
    /// Loads the four genesis files a node config names.
    /// - Parameters:
    ///   - nodeConfig: The node config.
    ///   - era: The era.
    ///   - inDirectory: The directory the genesis file paths are relative to, or
    ///     `nil` to use them as they are.
    /// - Throws: When a genesis file cannot be read or decoded.
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
    
    /// Creates genesis parameters from the four genesis files, taking the
    /// Shelley values from `shelleyGenesis`.
    /// - Parameters:
    ///   - alonzoGenesis: The Alonzo genesis.
    ///   - byronGenesis: The Byron genesis.
    ///   - conwayGenesis: The Conway genesis.
    ///   - shelleyGenesis: The Shelley genesis.
    ///   - era: The era.
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
    
    /// Creates genesis parameters from Shelley genesis values alone, with no
    /// genesis files.
    /// - Parameters:
    ///   - activeSlotsCoefficient: The `activeSlotsCoeff`.
    ///   - epochLength: The epoch length, in slots.
    ///   - maxKesEvolutions: The `maxKESEvolutions`.
    ///   - maxLovelaceSupply: The `maxLovelaceSupply`, in lovelace.
    ///   - networkId: `"Mainnet"` or `"Testnet"`.
    ///   - networkMagic: The network magic.
    ///   - securityParam: The security parameter.
    ///   - slotLength: The slot length, in seconds.
    ///   - slotsPerKesPeriod: The `slotsPerKESPeriod`.
    ///   - systemStart: The system start time.
    ///   - updateQuorum: The `updateQuorum`.
    ///   - era: The era.
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
