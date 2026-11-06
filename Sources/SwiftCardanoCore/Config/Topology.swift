import Foundation

/// A node topology file (`topology.json`): the peers the node connects to.
public struct Topology: JSONLoadable {
    /// The `bootstrapPeers` the node syncs from before it trusts ledger peers.
    public let bootstrapPeers: [BootstrapPeer]
    /// The `localRoots` groups of peers.
    public let localRoots: [LocalRoot]
    /// The `publicRoots` groups of peers.
    public let publicRoots: [PublicRoot]
    /// The `useLedgerAfterSlot` value: the slot after which the node may take peers from the ledger.
    public let useLedgerAfterSlot: Int
    
    /// Creates a topology from its fields.
    /// - Parameters:
    ///   - bootstrapPeers: The bootstrap peers.
    ///   - localRoots: The local root groups.
    ///   - publicRoots: The public root groups.
    ///   - useLedgerAfterSlot: The slot after which ledger peers may be used.
    public init(
        bootstrapPeers: [BootstrapPeer],
        localRoots: [LocalRoot],
        publicRoots: [PublicRoot],
        useLedgerAfterSlot: Int
    ) {
        self.bootstrapPeers = bootstrapPeers
        self.localRoots = localRoots
        self.publicRoots = publicRoots
        self.useLedgerAfterSlot = useLedgerAfterSlot
    }
}

/// One entry of a topology's `bootstrapPeers`.
public struct BootstrapPeer: Codable, Equatable, Hashable, Sendable {
    /// The peer's host name or IP address.
    public let address: String
    /// The peer's TCP port.
    public let port: Int
    
    /// Creates a bootstrap peer.
    /// - Parameters:
    ///   - address: The peer's host name or IP address.
    ///   - port: The peer's TCP port.
    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }
}

/// One group of a topology's `localRoots`.
public struct LocalRoot: Codable, Equatable, Hashable, Sendable {
    /// The group's `accessPoints`, as the file writes them.
    public let accessPoints: [String]
    /// The `advertise` flag: whether these peers may be shared with other nodes.
    public let advertise: Bool
    /// The `trustable` flag: whether the node trusts these peers while syncing.
    public let trustable: Bool
    /// The `valency`: how many peers of the group to keep connected.
    public let valency: Int
    
    /// Creates a local root group.
    /// - Parameters:
    ///   - accessPoints: The group's access points.
    ///   - advertise: Whether these peers may be shared with other nodes.
    ///   - trustable: Whether the node trusts these peers while syncing.
    ///   - valency: How many peers of the group to keep connected.
    public init(
        accessPoints: [String],
        advertise: Bool,
        trustable: Bool,
        valency: Int
    ) {
        self.accessPoints = accessPoints
        self.advertise = advertise
        self.trustable = trustable
        self.valency = valency
    }
}

/// One group of a topology's `publicRoots`.
public struct PublicRoot: Codable, Equatable, Hashable, Sendable {
    /// The group's `accessPoints`, as the file writes them.
    public let accessPoints: [String]
    /// The `advertise` flag: whether these peers may be shared with other nodes.
    public let advertise: Bool
    
    /// Creates a public root group.
    /// - Parameters:
    ///   - accessPoints: The group's access points.
    ///   - advertise: Whether these peers may be shared with other nodes.
    public init(accessPoints: [String], advertise: Bool) {
        self.accessPoints = accessPoints
        self.advertise = advertise
    }
} 
