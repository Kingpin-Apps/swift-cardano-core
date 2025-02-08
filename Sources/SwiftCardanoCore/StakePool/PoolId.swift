import Foundation

func isBech32CardanoPoolId(_ poolId: String?) -> Bool {
    guard let poolId = poolId, poolId.hasPrefix("pool") else {
        return false
    }
     let decoded = try? Bech32().bech32Decode(poolId)
    return decoded != nil
}

struct PoolId: Codable, CustomStringConvertible, CustomDebugStringConvertible, Equatable, Hashable {

    var description: String { return value }

    var debugDescription: String { return value }

    let value: String
    
    init(value: String) throws {
        guard isBech32CardanoPoolId(value) else {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(value: value)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
