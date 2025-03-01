import Foundation

public struct NodeConfig: ConfigFile {
    public let alonzoGenesisFile: String
    public let alonzoGenesisHash: String
    public let byronGenesisFile: String
    public let byronGenesisHash: String
    public let conwayGenesisFile: String
    public let conwayGenesisHash: String
    public let enableP2P: Bool
    public let lastKnownBlockVersionAlt: Int
    public let lastKnownBlockVersionMajor: Int
    public let lastKnownBlockVersionMinor: Int
    public let maxKnownMajorProtocolVersion: Int
    public let minNodeVersion: String
    public let peerSharing: Bool
    public let _protocol: String
    public let requiresNetworkMagic: String
    public let shelleyGenesisFile: String
    public let shelleyGenesisHash: String
    public let targetNumberOfActivePeers: Int
    public let targetNumberOfEstablishedPeers: Int
    public let targetNumberOfKnownPeers: Int
    public let targetNumberOfRootPeers: Int
    
    // Tracing configurations
    public let traceAcceptPolicy: Bool
    public let traceBlockFetchClient: Bool
    public let traceBlockFetchDecisions: Bool
    public let traceBlockFetchProtocol: Bool
    public let traceBlockFetchProtocolSerialised: Bool
    public let traceBlockFetchServer: Bool
    public let traceChainDb: Bool
    public let traceChainSyncBlockServer: Bool
    public let traceChainSyncClient: Bool
    public let traceChainSyncHeaderServer: Bool
    public let traceChainSyncProtocol: Bool
    public let traceConnectionManager: Bool
    public let traceDNSResolver: Bool
    public let traceDNSSubscription: Bool
    public let traceDiffusionInitialization: Bool
    public let traceErrorPolicy: Bool
    public let traceForge: Bool
    public let traceHandshake: Bool
    public let traceInboundGovernor: Bool
    public let traceIpSubscription: Bool
    public let traceLedgerPeers: Bool
    public let traceLocalChainSyncProtocol: Bool
    public let traceLocalConnectionManager: Bool
    public let traceLocalErrorPolicy: Bool
    public let traceLocalHandshake: Bool
    public let traceLocalRootPeers: Bool
    public let traceLocalTxSubmissionProtocol: Bool
    public let traceLocalTxSubmissionServer: Bool
    public let traceMempool: Bool
    public let traceMux: Bool
    public let tracePeerSelection: Bool
    public let tracePeerSelectionActions: Bool
    public let tracePublicRootPeers: Bool
    public let traceServer: Bool
    public let traceTxInbound: Bool
    public let traceTxOutbound: Bool
    public let traceTxSubmissionProtocol: Bool
    public let tracingVerbosity: String
    public let turnOnLogMetrics: Bool
    public let turnOnLogging: Bool
    
    public let defaultBackends: [String]
    public let defaultScribes: [[String]]
    public let hasEKG: Int
    public let hasPrometheus: PrometheusConfig
    public let minSeverity: String
    public let options: Options
    public let rotation: Rotation
    public let setupBackends: [String]
    public let setupScribes: [SetupScribe]
    
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

public struct PrometheusConfig: Codable, Equatable, Hashable {
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

public struct Options: Codable, Equatable, Hashable {
    public let mapBackends: [String: [String]]
    public let mapSubtrace: [String: SubtraceConfig]
    
    private enum CodingKeys: String, CodingKey {
        case mapBackends, mapSubtrace
    }
}

public struct SubtraceConfig: Codable, Equatable, Hashable {
    public let subtrace: String
}

public struct Rotation: Codable, Equatable, Hashable {
    public let rpKeepFilesNum: Int
    public let rpLogLimitBytes: Int
    public let rpMaxAgeHours: Int
}

public struct SetupScribe: Codable, Equatable, Hashable {
    public let scFormat: String
    public let scKind: String
    public let scName: String
    public let scRotation: String?
} 
