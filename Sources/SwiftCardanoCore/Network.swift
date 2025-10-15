import Foundation

/// Network ID
public enum NetworkId: Int, Codable, CaseIterable, Sendable {
    case testnet = 0
    case mainnet = 1
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        
        guard let network = NetworkId(rawValue: value) else {
            throw CardanoCoreError.valueError("Invalid network value: \(value)")
        }
        self = network
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

/// Network
public enum Network: Sendable, Equatable {
    case mainnet
    case preprod
    case preview
    case guildnet
    case sanchonet
    case custom(Int)
    
    /// Returns the testnet magic for the network
    public var testnetMagic: Int? {
        switch self {
            case .mainnet:
                return nil
            case .preprod:
                return 1
            case .preview:
                return 2
            case .guildnet:
                return 141
            case .sanchonet:
                return 4
            case .custom(let magic):
                return magic
        }
    }
    
    /// Returns the description for the network
    public var description: String {
        switch self {
            case .mainnet:
                return "mainnet"
            case .preprod:
                return "preprod"
            case .preview:
                return "preview"
            case .guildnet:
                return "guildnet"
            case .sanchonet:
                return "sanchonet"
            case .custom(let magic):
                return "custom(\(magic))"
        }
    }
    
    /// Returns the SwiftCardanoCore.Network for the network
    public var networkId: NetworkId {
        switch self {
            case .mainnet:
                return .mainnet
            default:
                return .testnet
        }
    }
}
