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

// MARK: - Codable

extension Network: CustomStringConvertible {}

extension Network: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            switch stringValue.lowercased() {
            case "mainnet": self = .mainnet
            case "preprod": self = .preprod
            case "preview": self = .preview
            case "guildnet": self = .guildnet
            case "sanchonet": self = .sanchonet
            default:
                if let magic = Int(stringValue) { self = .custom(magic) } else { self = .mainnet }
            }
        } else if let intValue = try? container.decode(Int.self) {
            self = .custom(intValue)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid network value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .mainnet: try container.encode("mainnet")
        case .preprod: try container.encode("preprod")
        case .preview: try container.encode("preview")
        case .guildnet: try container.encode("guildnet")
        case .sanchonet: try container.encode("sanchonet")
        case .custom(let magic): try container.encode(magic)
        }
    }
}
