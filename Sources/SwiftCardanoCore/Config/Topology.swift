import Foundation

public struct Topology: ConfigFile {
    public let bootstrapPeers: [BootstrapPeer]
    public let localRoots: [LocalRoot]
    public let publicRoots: [PublicRoot]
    public let useLedgerAfterSlot: Int
    
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

public struct BootstrapPeer: Codable, Equatable, Hashable {
    public let address: String
    public let port: Int
    
    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }
}

public struct LocalRoot: Codable, Equatable, Hashable {
    public let accessPoints: [String]
    public let advertise: Bool
    public let trustable: Bool
    public let valency: Int
    
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

public struct PublicRoot: Codable, Equatable, Hashable {
    public let accessPoints: [String]
    public let advertise: Bool
    
    public init(accessPoints: [String], advertise: Bool) {
        self.accessPoints = accessPoints
        self.advertise = advertise
    }
} 
