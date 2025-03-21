import Foundation

public func isBech32CardanoPoolId(_ poolId: String?) -> Bool {
    guard let poolId = poolId, poolId.hasPrefix("pool") else {
        return false
    }
    let decoded = try? Bech32().bech32Decode(poolId)
    return decoded != nil
}

public struct PoolId: Codable, CustomStringConvertible, CustomDebugStringConvertible, Equatable, Hashable {

    public var description: String { return bech32 }

    public var debugDescription: String { return bech32 }

    public var hex: String { Bech32().decode(addr: bech32)!.toHex }

    public let bech32: String
    
    public init(from bech32: String) throws {
        guard isBech32CardanoPoolId(bech32) else {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        self.bech32 = bech32
    }
    
    public init(from hex: Data) throws {
        let hexData = Bech32().encode(hrp: "pool", witprog: hex)
        
        if hexData == nil {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        
        try self.init(from: hexData!)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let bech32 = try container.decode(String.self)
        try self.init(from: bech32)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(bech32)
    }
    
    /// Load file contents from a given path
    /// - Parameter path: The path to the file
    /// - Returns: An instance of the conforming type
    public static func load(from path: String) throws -> Self {
        let id = try String(contentsOfFile: path).trimmingCharacters(in: .newlines)
        
        if id.hasPrefix("pool") {
            return try self.init(from: id)
        } else {
            return try self.init(from: id.hexStringToData)
        }
    }
}
