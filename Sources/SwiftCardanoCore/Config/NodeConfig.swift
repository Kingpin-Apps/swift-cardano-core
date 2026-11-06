import Foundation

/// A cardano-node configuration file (`config.json`), with the keys the node reads.
public struct NodeConfig: JSONLoadable {
    /// The path to the Alonzo genesis file, `AlonzoGenesisFile`.
    public let alonzoGenesisFile: String
    /// The hash of the Alonzo genesis file, `AlonzoGenesisHash`.
    public let alonzoGenesisHash: String?
    /// The path to the Byron genesis file, `ByronGenesisFile`.
    public let byronGenesisFile: String
    /// The hash of the Byron genesis file, `ByronGenesisHash`.
    public let byronGenesisHash: String?
    /// The path to the Conway genesis file, `ConwayGenesisFile`.
    public let conwayGenesisFile: String
    /// The hash of the Conway genesis file, `ConwayGenesisHash`.
    public let conwayGenesisHash: String?
    /// Whether peer-to-peer networking is enabled, `EnableP2P`.
    public let enableP2P: Bool?
    /// The Byron protocol version the node supports: `Word8` for the alt
    /// version, `Word16` for the major and minor (cardano-node
    /// `NodeByronProtocolConfiguration`).
    public let lastKnownBlockVersionAlt: UInt8?
    /// The Byron protocol major version, `LastKnownBlockVersion-Major`.
    public let lastKnownBlockVersionMajor: UInt16?
    /// The Byron protocol minor version, `LastKnownBlockVersion-Minor`.
    public let lastKnownBlockVersionMinor: UInt16?
    /// A legacy field the node no longer reads; it was a `Natural`.
    public let maxKnownMajorProtocolVersion: UInt64?
    /// The lowest node version this config is for, `MinNodeVersion`.
    public let minNodeVersion: String?
    /// Whether peer sharing is enabled, `PeerSharing`.
    public let peerSharing: Bool?
    /// The consensus protocol, `Protocol`.
    public let _protocol: String?
    /// The `RequiresNetworkMagic` setting, as the file writes it.
    public let requiresNetworkMagic: String?
    /// The path to the Shelley genesis file, `ShelleyGenesisFile`.
    public let shelleyGenesisFile: String
    /// The hash of the Shelley genesis file, `ShelleyGenesisHash`.
    public let shelleyGenesisHash: String?
    /// The target number of active peers, `TargetNumberOfActivePeers`.
    public let targetNumberOfActivePeers: Int?
    /// The target number of established peers, `TargetNumberOfEstablishedPeers`.
    public let targetNumberOfEstablishedPeers: Int?
    /// The target number of known peers, `TargetNumberOfKnownPeers`.
    public let targetNumberOfKnownPeers: Int?
    /// The target number of root peers, `TargetNumberOfRootPeers`.
    public let targetNumberOfRootPeers: Int?

    /// Whether hard forks to unreleased eras are enabled.
    public let experimentalHardForksEnabled: Bool?
    /// The epoch of the test hard fork to Shelley, `TestShelleyHardForkAtEpoch`.
    ///
    /// Each test hard-fork epoch is an `EpochNo`, a `Word64`.
    public let testShelleyHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Allegra, `TestAllegraHardForkAtEpoch`.
    public let testAllegraHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Mary, `TestMaryHardForkAtEpoch`.
    public let testMaryHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Alonzo, `TestAlonzoHardForkAtEpoch`.
    public let testAlonzoHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Babbage, `TestBabbageHardForkAtEpoch`.
    public let testBabbageHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Conway, `TestConwayHardForkAtEpoch`.
    public let testConwayHardForkAtEpoch: EpochNumber?
    /// The epoch of the test hard fork to Dijkstra, `TestDijkstraHardForkAtEpoch`.
    public let testDijkstraHardForkAtEpoch: EpochNumber?
    /// The protocol version of the test hard fork to Shelley, `TestShelleyHardForkAtVersion`.
    ///
    /// Each test hard-fork protocol version is a `Word`.
    public let testShelleyHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Allegra, `TestAllegraHardForkAtVersion`.
    public let testAllegraHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Mary, `TestMaryHardForkAtVersion`.
    public let testMaryHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Alonzo, `TestAlonzoHardForkAtVersion`.
    public let testAlonzoHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Babbage, `TestBabbageHardForkAtVersion`.
    public let testBabbageHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Conway, `TestConwayHardForkAtVersion`.
    public let testConwayHardForkAtVersion: UInt64?
    /// The protocol version of the test hard fork to Dijkstra, `TestDijkstraHardForkAtVersion`.
    public let testDijkstraHardForkAtVersion: UInt64?
    
    // Tracing configurations
    /// Whether the `TraceAcceptPolicy` tracer is on.
    public let traceAcceptPolicy: Bool?
    /// Whether the `TraceBlockFetchClient` tracer is on.
    public let traceBlockFetchClient: Bool?
    /// Whether the `TraceBlockFetchDecisions` tracer is on.
    public let traceBlockFetchDecisions: Bool?
    /// Whether the `TraceBlockFetchProtocol` tracer is on.
    public let traceBlockFetchProtocol: Bool?
    /// Whether the `TraceBlockFetchProtocolSerialised` tracer is on.
    public let traceBlockFetchProtocolSerialised: Bool?
    /// Whether the `TraceBlockFetchServer` tracer is on.
    public let traceBlockFetchServer: Bool?
    /// Whether the `TraceChainDb` tracer is on.
    public let traceChainDb: Bool?
    /// Whether the `TraceChainSyncBlockServer` tracer is on.
    public let traceChainSyncBlockServer: Bool?
    /// Whether the `TraceChainSyncClient` tracer is on.
    public let traceChainSyncClient: Bool?
    /// Whether the `TraceChainSyncHeaderServer` tracer is on.
    public let traceChainSyncHeaderServer: Bool?
    /// Whether the `TraceChainSyncProtocol` tracer is on.
    public let traceChainSyncProtocol: Bool?
    /// Whether the `TraceConnectionManager` tracer is on.
    public let traceConnectionManager: Bool?
    /// Whether the `TraceDNSResolver` tracer is on.
    public let traceDNSResolver: Bool?
    /// Whether the `TraceDNSSubscription` tracer is on.
    public let traceDNSSubscription: Bool?
    /// Whether the `TraceDiffusionInitialization` tracer is on.
    public let traceDiffusionInitialization: Bool?
    /// Whether the `TraceErrorPolicy` tracer is on.
    public let traceErrorPolicy: Bool?
    /// Whether the `TraceForge` tracer is on.
    public let traceForge: Bool?
    /// Whether the `TraceHandshake` tracer is on.
    public let traceHandshake: Bool?
    /// Whether the `TraceInboundGovernor` tracer is on.
    public let traceInboundGovernor: Bool?
    /// Whether the `TraceIpSubscription` tracer is on.
    public let traceIpSubscription: Bool?
    /// Whether the `TraceLedgerPeers` tracer is on.
    public let traceLedgerPeers: Bool?
    /// Whether the `TraceLocalChainSyncProtocol` tracer is on.
    public let traceLocalChainSyncProtocol: Bool?
    /// Whether the `TraceLocalConnectionManager` tracer is on.
    public let traceLocalConnectionManager: Bool?
    /// Whether the `TraceLocalErrorPolicy` tracer is on.
    public let traceLocalErrorPolicy: Bool?
    /// Whether the `TraceLocalHandshake` tracer is on.
    public let traceLocalHandshake: Bool?
    /// Whether the `TraceLocalRootPeers` tracer is on.
    public let traceLocalRootPeers: Bool?
    /// Whether the `TraceLocalTxSubmissionProtocol` tracer is on.
    public let traceLocalTxSubmissionProtocol: Bool?
    /// Whether the `TraceLocalTxSubmissionServer` tracer is on.
    public let traceLocalTxSubmissionServer: Bool?
    /// Whether the `TraceMempool` tracer is on.
    public let traceMempool: Bool?
    /// Whether the `TraceMux` tracer is on.
    public let traceMux: Bool?
    /// Whether the `TracePeerSelection` tracer is on.
    public let tracePeerSelection: Bool?
    /// Whether the `TracePeerSelectionActions` tracer is on.
    public let tracePeerSelectionActions: Bool?
    /// Whether the `TracePublicRootPeers` tracer is on.
    public let tracePublicRootPeers: Bool?
    /// Whether the `TraceServer` tracer is on.
    public let traceServer: Bool?
    /// Whether the `TraceTxInbound` tracer is on.
    public let traceTxInbound: Bool?
    /// Whether the `TraceTxOutbound` tracer is on.
    public let traceTxOutbound: Bool?
    /// Whether the `TraceTxSubmissionProtocol` tracer is on.
    public let traceTxSubmissionProtocol: Bool?
    /// The tracing verbosity, `TracingVerbosity`.
    public let tracingVerbosity: String?
    /// Whether log metrics are on, `TurnOnLogMetrics`.
    public let turnOnLogMetrics: Bool?
    /// Whether logging is on, `TurnOnLogging`.
    public let turnOnLogging: Bool?
    
    /// The legacy logging `defaultBackends`.
    public let defaultBackends: [String]?
    /// The legacy logging `defaultScribes`: each a scribe kind and name.
    public let defaultScribes: [[String]]?
    /// The legacy logging `hasEKG` port.
    public let hasEKG: Int?
    /// The legacy logging `hasPrometheus` host and port.
    public let hasPrometheus: PrometheusConfig?
    /// The legacy logging `minSeverity`.
    public let minSeverity: String?
    /// The legacy logging `options` block.
    public let options: Options?
    /// The legacy logging `rotation` settings.
    public let rotation: Rotation?
    /// The legacy logging `setupBackends`.
    public let setupBackends: [String]?
    /// The legacy logging `setupScribes`.
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

/// The legacy logging `hasPrometheus` value, a JSON array of host and port.
public struct PrometheusConfig: Codable, Equatable, Hashable, Sendable {
    /// The host the Prometheus endpoint listens on.
    public let host: String
    /// The port the Prometheus endpoint listens on.
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

/// The legacy logging `options` block of a node config.
public struct Options: Codable, Equatable, Hashable, Sendable {
    // Optional: a node config's logging `options` block is frequently empty
    // (`"options": {}`) — e.g. the current preview/preprod configs — and these
    // legacy iohk-monitoring fields are irrelevant to everything we read from a
    // node config (genesis file paths, etc.). Requiring them made `NodeConfig.load`
    // (and `GenesisParameters(nodeConfigFilePath:)`) throw `keyNotFound`.
    /// The `mapBackends` option: backends by trace name.
    public let mapBackends: [String: [String]]?
    /// The `mapSubtrace` option: subtrace settings by trace name.
    public let mapSubtrace: [String: SubtraceConfig]?

    private enum CodingKeys: String, CodingKey {
        case mapBackends, mapSubtrace
    }
}

/// One entry of the logging `mapSubtrace` option.
public struct SubtraceConfig: Codable, Equatable, Hashable, Sendable {
    /// The `subtrace` setting.
    public let subtrace: String
}

/// iohk-monitoring's `RotationParameters`: `Word64` for the byte limit,
/// `Word` for the others.
public struct Rotation: Codable, Equatable, Hashable, Sendable {
    /// The number of rotated log files to keep, `rpKeepFilesNum`.
    public let rpKeepFilesNum: UInt64
    /// The size at which a log file is rotated, in bytes, `rpLogLimitBytes`.
    public let rpLogLimitBytes: UInt64
    /// The age at which a log file is rotated, in hours, `rpMaxAgeHours`.
    public let rpMaxAgeHours: UInt64
}

/// One entry of the legacy logging `setupScribes`.
public struct SetupScribe: Codable, Equatable, Hashable, Sendable {
    /// The scribe's output format, `scFormat`.
    public let scFormat: String
    /// The scribe's kind, `scKind`.
    public let scKind: String
    /// The scribe's name, `scName`.
    public let scName: String
    /// The scribe's rotation setting, `scRotation`.
    public let scRotation: String?
} 
