import Foundation

/// Network ID
enum Network: Int, Codable, CaseIterable {
    case testnet = 0
    case mainnet = 1
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        
        guard let network = Network(rawValue: value) else {
            throw CardanoCoreError.valueError("Invalid network value: \(value)")
        }
        self = network
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
