import Foundation

/// The network ID carried in a Shelley address header and a transaction body:
/// `0` for any test network, `1` for mainnet.
public enum NetworkId: Int, Codable, CaseIterable, Sendable {
    /// Any test network.
    case testnet = 0
    /// The Cardano mainnet.
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

/// A Cardano network, which sets the network ID and, for a test network, its magic.
public enum Network: Sendable, Equatable {
    /// The Cardano mainnet.
    case mainnet
    /// The preprod test network, magic `1`.
    case preprod
    /// The preview test network, magic `2`.
    case preview
    /// The guildnet test network, magic `141`.
    case guildnet
    /// The SanchoNet test network, magic `4`.
    case sanchonet
    /// A test network with the given magic.
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
    /// The network a magic stands for: a named case for the known magics,
    /// including mainnet's `764824073`, and ``custom(_:)`` otherwise.
    static func fromMagic(_ magic: Int) -> Network {
        switch magic {
        case 764_824_073: return .mainnet
        case 1: return .preprod
        case 2: return .preview
        case 4: return .sanchonet
        case 141: return .guildnet
        default: return .custom(magic)
        }
    }

    /// Reads a network from a name (any case) or a magic, given as an integer
    /// or a decimal string. A known magic reads as its named case.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for any other value, so a
    ///   misspelt or unknown name is never read as mainnet.
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
                guard let magic = Int(stringValue) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Unknown network name \"\(stringValue)\""))
                }
                self = Self.fromMagic(magic)
            }
        } else if let intValue = try? container.decode(Int.self) {
            self = Self.fromMagic(intValue)
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
