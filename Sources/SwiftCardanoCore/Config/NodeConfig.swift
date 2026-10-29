import Foundation

public struct NodeConfig: JSONLoadable {
    public let alonzoGenesisFile: String
    public let alonzoGenesisHash: String?
    public let byronGenesisFile: String
    public let byronGenesisHash: String?
    public let conwayGenesisFile: String
    public let conwayGenesisHash: String?
    public let enableP2P: Bool?
    /// The Byron protocol version the node supports: `Word8` for the alt
    /// version, `Word16` for the major and minor (cardano-node
    /// `NodeByronProtocolConfiguration`).
    public let lastKnownBlockVersionAlt: UInt8?
    public let lastKnownBlockVersionMajor: UInt16?
    public let lastKnownBlockVersionMinor: UInt16?
    /// A legacy field the node no longer reads; it was a `Natural`.
    public let maxKnownMajorProtocolVersion: UInt64?
    public let minNodeVersion: String?
    public let peerSharing: Bool?
    public let _protocol: String?
    public let requiresNetworkMagic: String?
    public let shelleyGenesisFile: String
    public let shelleyGenesisHash: String?
    public let targetNumberOfActivePeers: Int?
    public let targetNumberOfEstablishedPeers: Int?
    public let targetNumberOfKnownPeers: Int?
    public let targetNumberOfRootPeers: Int?

    /// Whether hard forks to unreleased eras are enabled.
    public let experimentalHardForksEnabled: Bool?
    /// Test hard-fork epochs: each an `EpochNo`, a `Word64`.
    public let testShelleyHardForkAtEpoch: EpochNumber?
    public let testAllegraHardForkAtEpoch: EpochNumber?
    public let testMaryHardForkAtEpoch: EpochNumber?
    public let testAlonzoHardForkAtEpoch: EpochNumber?
    public let testBabbageHardForkAtEpoch: EpochNumber?
    public let testConwayHardForkAtEpoch: EpochNumber?
    public let testDijkstraHardForkAtEpoch: EpochNumber?
    /// Test hard-fork protocol versions: each a `Word`.
    public let testShelleyHardForkAtVersion: UInt64?
    public let testAllegraHardForkAtVersion: UInt64?
    public let testMaryHardForkAtVersion: UInt64?
    public let testAlonzoHardForkAtVersion: UInt64?
    public let testBabbageHardForkAtVersion: UInt64?
    public let testConwayHardForkAtVersion: UInt64?
    public let testDijkstraHardForkAtVersion: UInt64?
    
    // Tracing configurations
    public let traceAcceptPolicy: Bool?
    public let traceBlockFetchClient: Bool?
    public let traceBlockFetchDecisions: Bool?
    public let traceBlockFetchProtocol: Bool?
    public let traceBlockFetchProtocolSerialised: Bool?
    public let traceBlockFetchServer: Bool?
    public let traceChainDb: Bool?
    public let traceChainSyncBlockServer: Bool?
    public let traceChainSyncClient: Bool?
    public let traceChainSyncHeaderServer: Bool?
    public let traceChainSyncProtocol: Bool?
    public let traceConnectionManager: Bool?
    public let traceDNSResolver: Bool?
    public let traceDNSSubscription: Bool?
    public let traceDiffusionInitialization: Bool?
    public let traceErrorPolicy: Bool?
    public let traceForge: Bool?
    public let traceHandshake: Bool?
    public let traceInboundGovernor: Bool?
    public let traceIpSubscription: Bool?
    public let traceLedgerPeers: Bool?
    public let traceLocalChainSyncProtocol: Bool?
    public let traceLocalConnectionManager: Bool?
    public let traceLocalErrorPolicy: Bool?
    public let traceLocalHandshake: Bool?
    public let traceLocalRootPeers: Bool?
    public let traceLocalTxSubmissionProtocol: Bool?
    public let traceLocalTxSubmissionServer: Bool?
    public let traceMempool: Bool?
    public let traceMux: Bool?
    public let tracePeerSelection: Bool?
    public let tracePeerSelectionActions: Bool?
    public let tracePublicRootPeers: Bool?
    public let traceServer: Bool?
    public let traceTxInbound: Bool?
    public let traceTxOutbound: Bool?
    public let traceTxSubmissionProtocol: Bool?
    public let tracingVerbosity: String?
    public let turnOnLogMetrics: Bool?
    public let turnOnLogging: Bool?
    
    public let defaultBackends: [String]?
    public let defaultScribes: [[String]]?
    public let hasEKG: Int?
    public let hasPrometheus: PrometheusConfig?
    public let minSeverity: String?
    public let options: Options?
    public let rotation: Rotation?
    public let setupBackends: [String]?
    public let setupScribes: [SetupScribe]?
    
    private enum CodingKeys: String, CodingKey {
        case alonzoGenesisFile = "AlonzoGenesisFile"
        case alonzoGenesisHash = "AlonzoGenesisHash"
        case byronGenesisFile = "ByronGenesisFile"
        case byronGenesisHash = "ByronGenesisHash"
        case conwayGenesisFile = "ConwayGenesisFile"
        case conwayGenesisHash = "ConwayGenesisHash"
        case enableP2P = "EnableP2P"
        case lastKnownBlockVersionAlt = "LastKnownBlockVersion-Alt"
        case lastKnownBlockVersionMajor = "LastKnownBlockVersion-Major"
        case lastKnownBlockVersionMinor = "LastKnownBlockVersion-Minor"
        case maxKnownMajorProtocolVersion = "MaxKnownMajorProtocolVersion"
        case minNodeVersion = "MinNodeVersion"
        case peerSharing = "PeerSharing"
        case _protocol = "Protocol"
        case requiresNetworkMagic = "RequiresNetworkMagic"
        case shelleyGenesisFile = "ShelleyGenesisFile"
        case shelleyGenesisHash = "ShelleyGenesisHash"
        case targetNumberOfActivePeers = "TargetNumberOfActivePeers"
        case targetNumberOfEstablishedPeers = "TargetNumberOfEstablishedPeers"
        case targetNumberOfKnownPeers = "TargetNumberOfKnownPeers"
        case targetNumberOfRootPeers = "TargetNumberOfRootPeers"
        case experimentalHardForksEnabled = "ExperimentalHardForksEnabled"
        case testShelleyHardForkAtEpoch = "TestShelleyHardForkAtEpoch"
        case testAllegraHardForkAtEpoch = "TestAllegraHardForkAtEpoch"
        case testMaryHardForkAtEpoch = "TestMaryHardForkAtEpoch"
        case testAlonzoHardForkAtEpoch = "TestAlonzoHardForkAtEpoch"
        case testBabbageHardForkAtEpoch = "TestBabbageHardForkAtEpoch"
        case testConwayHardForkAtEpoch = "TestConwayHardForkAtEpoch"
        case testDijkstraHardForkAtEpoch = "TestDijkstraHardForkAtEpoch"
        case testShelleyHardForkAtVersion = "TestShelleyHardForkAtVersion"
        case testAllegraHardForkAtVersion = "TestAllegraHardForkAtVersion"
        case testMaryHardForkAtVersion = "TestMaryHardForkAtVersion"
        case testAlonzoHardForkAtVersion = "TestAlonzoHardForkAtVersion"
        case testBabbageHardForkAtVersion = "TestBabbageHardForkAtVersion"
        case testConwayHardForkAtVersion = "TestConwayHardForkAtVersion"
        case testDijkstraHardForkAtVersion = "TestDijkstraHardForkAtVersion"
        case traceAcceptPolicy = "TraceAcceptPolicy"
        case traceBlockFetchClient = "TraceBlockFetchClient"
        case traceBlockFetchDecisions = "TraceBlockFetchDecisions"
        case traceBlockFetchProtocol = "TraceBlockFetchProtocol"
        case traceBlockFetchProtocolSerialised = "TraceBlockFetchProtocolSerialised"
        case traceBlockFetchServer = "TraceBlockFetchServer"
        case traceChainDb = "TraceChainDb"
        case traceChainSyncBlockServer = "TraceChainSyncBlockServer"
        case traceChainSyncClient = "TraceChainSyncClient"
        case traceChainSyncHeaderServer = "TraceChainSyncHeaderServer"
        case traceChainSyncProtocol = "TraceChainSyncProtocol"
        case traceConnectionManager = "TraceConnectionManager"
        case traceDNSResolver = "TraceDNSResolver"
        case traceDNSSubscription = "TraceDNSSubscription"
        case traceDiffusionInitialization = "TraceDiffusionInitialization"
        case traceErrorPolicy = "TraceErrorPolicy"
        case traceForge = "TraceForge"
        case traceHandshake = "TraceHandshake"
        case traceInboundGovernor = "TraceInboundGovernor"
        case traceIpSubscription = "TraceIpSubscription"
        case traceLedgerPeers = "TraceLedgerPeers"
        case traceLocalChainSyncProtocol = "TraceLocalChainSyncProtocol"
        case traceLocalConnectionManager = "TraceLocalConnectionManager"
        case traceLocalErrorPolicy = "TraceLocalErrorPolicy"
        case traceLocalHandshake = "TraceLocalHandshake"
        case traceLocalRootPeers = "TraceLocalRootPeers"
        case traceLocalTxSubmissionProtocol = "TraceLocalTxSubmissionProtocol"
        case traceLocalTxSubmissionServer = "TraceLocalTxSubmissionServer"
        case traceMempool = "TraceMempool"
        case traceMux = "TraceMux"
        case tracePeerSelection = "TracePeerSelection"
        case tracePeerSelectionActions = "TracePeerSelectionActions"
        case tracePublicRootPeers = "TracePublicRootPeers"
        case traceServer = "TraceServer"
        case traceTxInbound = "TraceTxInbound"
        case traceTxOutbound = "TraceTxOutbound"
        case traceTxSubmissionProtocol = "TraceTxSubmissionProtocol"
        case tracingVerbosity = "TracingVerbosity"
        case turnOnLogMetrics = "TurnOnLogMetrics"
        case turnOnLogging = "TurnOnLogging"
        case defaultBackends, defaultScribes, hasEKG, hasPrometheus, minSeverity
        case options, rotation, setupBackends, setupScribes
    }
}

public struct PrometheusConfig: Codable, Equatable, Hashable, Sendable {
    public let host: String
    public let port: Int
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        host = try container.decode(String.self)
        port = try container.decode(Int.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(host)
        try container.encode(port)
    }
}

public struct Options: Codable, Equatable, Hashable, Sendable {
    // Optional: a node config's logging `options` block is frequently empty
    // (`"options": {}`) — e.g. the current preview/preprod configs — and these
    // legacy iohk-monitoring fields are irrelevant to everything we read from a
    // node config (genesis file paths, etc.). Requiring them made `NodeConfig.load`
    // (and `GenesisParameters(nodeConfigFilePath:)`) throw `keyNotFound`.
    public let mapBackends: [String: [String]]?
    public let mapSubtrace: [String: SubtraceConfig]?

    private enum CodingKeys: String, CodingKey {
        case mapBackends, mapSubtrace
    }
}

public struct SubtraceConfig: Codable, Equatable, Hashable, Sendable {
    public let subtrace: String
}

/// iohk-monitoring's `RotationParameters`: `Word64` for the byte limit,
/// `Word` for the others.
public struct Rotation: Codable, Equatable, Hashable, Sendable {
    public let rpKeepFilesNum: UInt64
    public let rpLogLimitBytes: UInt64
    public let rpMaxAgeHours: UInt64
}

public struct SetupScribe: Codable, Equatable, Hashable, Sendable {
    public let scFormat: String
    public let scKind: String
    public let scName: String
    public let scRotation: String?
} 
