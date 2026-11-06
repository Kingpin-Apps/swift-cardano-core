import Foundation
import CBORCodable

/// Byte sizes of the fixed-length hashes and payloads in this module.
/// Key, script, pool key and genesis hashes are 28 bytes; transaction, datum,
/// script data, metadata, VRF key, KES key and block hashes are 32 bytes. A reward
/// account and a CIP-129 payload are 29 bytes: a header byte followed by a 28-byte
/// credential.
public let VERIFICATION_KEY_HASH_SIZE = 28,
SCRIPT_HASH_SIZE = 28,
SCRIPT_DATA_HASH_SIZE = 32,
TRANSACTION_HASH_SIZE = 32,
DATUM_HASH_SIZE = 32,
AUXILIARY_DATA_HASH_SIZE = 32,
POOL_KEY_HASH_SIZE = 28,
POOL_METADATA_HASH_SIZE = 32,
DREP_METADATA_HASH_SIZE = 32,
VRF_KEY_HASH_SIZE = 32,
REWARD_ACCOUNT_HASH_SIZE = 29,
GENESIS_HASH_SIZE = 28,
GENESIS_DELEGATE_HASH_SIZE = 28,
ADDRESS_KEY_HASH_SIZE = 28,
ANCHOR_DATA_HASH_SIZE = 32,
CIP129_PAYLOAD_SIZE = 29,
UTXO_HASH_SIZE = 32,
BLOCK_BODY_HASH_SIZE = 32,
BLOCK_HEADER_HASH_SIZE = 32,
KES_KEY_HASH_SIZE = 32

/// A protocol for byte arrays with constraints on their size.
public protocol ConstrainedBytes: Serializable {
    
    /// The raw bytes.
    var payload: Data { get set }
    /// The largest number of bytes ``payload`` may hold.
    static var maxSize: Int { get }
    /// The smallest number of bytes ``payload`` may hold.
    static var minSize: Int { get }
    
    /// Creates a value from raw bytes.
    /// - Parameter payload: The raw bytes.
    /// - Throws: When the type rejects `payload`.
    init(payload: Data) throws
}

extension ConstrainedBytes {
    /// `payload` as this type, when its size is within ``minSize`` and
    /// ``maxSize``: a hash of the wrong length is not that hash, and the ledger
    /// rejects it.
    static func checked(_ payload: Data) throws -> Self {
        guard payload.count >= minSize, payload.count <= maxSize else {
            throw CardanoCoreError.deserializeError(
                "\(Self.self) must be \(minSize == maxSize ? "\(maxSize)" : "\(minSize) to \(maxSize)") bytes, got \(payload.count)")
        }
        return try Self(payload: payload)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        self = try Self.checked(payload)
    }
    
    public init(from primitive: Primitive) throws {
        if case let .bytes(primitive) = primitive {
            self = try Self.checked(primitive)
        } else if case let .string(primitive) = primitive {
            self = try Self.checked(primitive.hexStringToData)
        } else {
            throw CardanoCoreError.deserializeError("Invalid \(Self.self) type: \(primitive)")
        }
    }
    
    public func toPrimitive() -> Primitive {
        return .bytes(payload)
    }
    
    public static func fromDict(_ primitive: Primitive) throws -> Self {
        if case let .bytes(primitive) = primitive {
            return try Self.checked(primitive)
        } else if case let .string(primitive) = primitive {
            let hexData = primitive.hexStringToData
            if hexData.count == Self.maxSize {
                return try Self.init(payload: hexData)
            } else if let data = Data(base64Encoded: primitive), data.count == Self.maxSize {
                return try Self.init(payload: data)
            } else {
                throw CardanoCoreError.deserializeError("Invalid \(Self.self) string format: neither valid hex nor base64")
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid \(Self.self) type: \(primitive)")
        }
    }
    
    public func toDict() throws -> Primitive {
        return .bytes(payload)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload
    }
    
    public var debugDescription: String {
        return "\(type(of: self))(hex=\(payload.toHex)"
    }
    
    public var description: String {
        return payload.toHex
    }
}

/// A 28-byte Blake2b-224 hash of a verification key.
public struct VerificationKeyHash: ConstrainedBytes, Hashable, Equatable {
    public var payload: Data
    public static var maxSize: Int { VERIFICATION_KEY_HASH_SIZE }
    public static var minSize: Int { VERIFICATION_KEY_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 28-byte hash of a native or Plutus script.
public struct ScriptHash: ConstrainedBytes, Hashable, Equatable {
    public var payload: Data
    public static var maxSize: Int { SCRIPT_HASH_SIZE }
    public static var minSize: Int { SCRIPT_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// The ID of a minting policy: the hash of its script.
public typealias PolicyID = ScriptHash
/// The hash of a minting policy script.
public typealias PolicyHash = ScriptHash

/// A 32-byte hash of a transaction's script data.
/// See: [alonzo.cddl](https://github.com/input-output-hk/cardano-ledger/blob/525844be05adae151e82069dcd0000f3301ca0d0/eras/alonzo/test-suite/cddl-files/alonzo.cddl#L79-L86)
public struct ScriptDataHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { SCRIPT_DATA_HASH_SIZE }
    public static var minSize: Int { SCRIPT_DATA_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte Blake2b-256 hash of a transaction body, which identifies the transaction.
public struct TransactionId: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { TRANSACTION_HASH_SIZE }
    public static var minSize: Int { TRANSACTION_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte Blake2b-256 hash of a datum's CBOR encoding.
public struct DatumHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { DATUM_HASH_SIZE }
    public static var minSize: Int { DATUM_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte hash of a transaction's auxiliary data.
public struct AuxiliaryDataHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { AUXILIARY_DATA_HASH_SIZE }
    public static var minSize: Int { AUXILIARY_DATA_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 28-byte Blake2b-224 hash of a stake pool's cold verification key; the pool ID.
public struct PoolKeyHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { POOL_KEY_HASH_SIZE }
    public static var minSize: Int { POOL_KEY_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte hash of a stake pool's metadata file.
public struct PoolMetadataHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { POOL_METADATA_HASH_SIZE }
    public static var minSize: Int { POOL_METADATA_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte Blake2b-256 hash of a VRF verification key.
public struct VrfKeyHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { VRF_KEY_HASH_SIZE }
    public static var minSize: Int { VRF_KEY_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 29-byte reward account: a reward address in binary form, a header byte
/// followed by a 28-byte stake credential. Despite the name, it is not a hash.
public struct RewardAccountHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { REWARD_ACCOUNT_HASH_SIZE }
    public static var minSize: Int { REWARD_ACCOUNT_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 28-byte hash of a genesis key.
public struct GenesisHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { GENESIS_HASH_SIZE }
    public static var minSize: Int { GENESIS_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 28-byte hash of a genesis delegate key.
public struct GenesisDelegateHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { GENESIS_DELEGATE_HASH_SIZE }
    public static var minSize: Int { GENESIS_DELEGATE_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 28-byte hash of an address key.
public struct AddressKeyHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { ADDRESS_KEY_HASH_SIZE }
    public static var minSize: Int { ADDRESS_KEY_HASH_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte hash of the document a governance anchor points to.
public struct AnchorDataHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { ANCHOR_DATA_HASH_SIZE }
    public static var minSize: Int { ANCHOR_DATA_HASH_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte hash of a block body.
public struct BlockBodyHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { BLOCK_BODY_HASH_SIZE }
    public static var minSize: Int { BLOCK_BODY_HASH_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}

/// A 32-byte hash of a block header.
public struct BlockHeaderHash: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { BLOCK_HEADER_HASH_SIZE }
    public static var minSize: Int { BLOCK_HEADER_HASH_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}
