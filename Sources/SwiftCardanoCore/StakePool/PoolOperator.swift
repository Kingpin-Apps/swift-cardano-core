import Foundation

public struct PoolOperator: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    
    public let poolKeyHash: PoolKeyHash
    
    public var description: String {
        do {
            return try self.toBech32()
        } catch {
            return "PoolOperator(invalid)"
        }
    }
    
    public var debugDescription: String { self.description }
    
    public init(poolKeyHash: PoolKeyHash) {
        self.poolKeyHash = poolKeyHash
    }
    
    public init(from bech32: String) throws {
        let _bech32 = Bech32()
        let (hrp, checksum, _) = try _bech32.bech32Decode(bech32)
        let data = _bech32.convertBits(data: checksum, fromBits: 5, toBits: 8, pad: false)
        
        guard let data, hrp == "pool" else {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        
        try self.init(from: data)
    }
    
    public init(from hex: Data) throws {
        let poolKeyHash = PoolKeyHash(payload: hex)
        let hexData = Bech32().encode(hrp: "pool", witprog: hex)
        
        if hexData == nil {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        
        self.init(poolKeyHash: poolKeyHash)
    }
    
    public init(from primitive: Primitive) throws {
        if case .string(let bech32) = primitive {
            try self.init(from: bech32)
        } else if case .bytes(let data) = primitive {
            try self.init(from: data)
        } else {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return poolKeyHash.toPrimitive()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let bech32 = try container.decode(String.self)
        try self.init(from: bech32)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try self.toBech32())
    }
    
    public func toBytes() throws -> Data {
        return self.poolKeyHash.payload
    }
        
    public func id(_ format: CredentialFormat = .bech32) throws -> String {
        switch format {
            case .bech32:
                return try self.toBech32()
            case .hex:
                return try self.toBytes().toHex
        }
    }
    
    /// Encode the PoolOperator in Bech32 format.
    ///
    /// More info about Bech32 (here)[https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#Bech32].
    
    /// - Returns: Encoded PoolOperator in Bech32.
    public func toBech32() throws -> String {
        let data = try self.toBytes()
        
        guard let encoded =  Bech32().encode(hrp: "pool", witprog: data) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(data)")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an PoolOperator object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded PoolOperator.
    public static func fromBech32(_ poolId: String) throws -> PoolOperator {
        return try PoolOperator(from: .string(poolId))
    }
    
    /// Validate if a given string is a valid bech32 PoolOperator ID.
    /// - Parameter poolId: The PoolOperator ID string.
    /// - Returns: True if valid, false otherwise.	
    public static func isValidBech32(_ poolId: String?) -> Bool {
        guard let poolId = poolId, poolId.hasPrefix("pool") else {
            return false
        }
        let decoded = try? Bech32().bech32Decode(poolId)
        return decoded != nil
    }
    
    /// Save the PoolOperator ID to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - format: The credential format (bech32 or hex)
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and overwrite is false.  
    public func save(
        to path: String,
        format: CredentialFormat,
        overwrite: Bool = false
    ) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        switch format {
            case .bech32:
                let bech32 = try self.toBech32()
                try bech32.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
            case .hex:
                let hex = try self.toBytes().toHex
                try hex.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        }
    }
    
    /// Load file contents from a given path
    /// - Parameter path: The path to the file
    /// - Returns: An instance of the conforming type
    public static func load(from path: String) throws -> Self {
        let id = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .newlines)
        
        if id.hasPrefix("pool") {
            return try self.init(from: id)
        } else {
            return try self.init(from: id.hexStringToData)
        }
    }
}
