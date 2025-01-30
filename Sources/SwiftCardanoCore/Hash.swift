import Foundation
import PotentCBOR

let VERIFICATION_KEY_HASH_SIZE = 28,
SCRIPT_HASH_SIZE = 28,
SCRIPT_DATA_HASH_SIZE = 32,
TRANSACTION_HASH_SIZE = 32,
DATUM_HASH_SIZE = 32,
AUXILIARY_DATA_HASH_SIZE = 32,
POOL_KEY_HASH_SIZE = 28,
POOL_METADATA_HASH_SIZE = 32,
VRF_KEY_HASH_SIZE = 32,
REWARD_ACCOUNT_HASH_SIZE = 29,
GENESIS_HASH_SIZE = 28,
GENESIS_DELEGATE_HASH_SIZE = 28,
ADDRESS_KEY_HASH_SIZE = 28,
ANCHOR_DATA_HASH_SIZE = 32

/// A protocol for byte arrays with constraints on their size.
protocol ConstrainedBytes: Codable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    
    var payload: Data { get set }
    static var maxSize: Int { get }
    static var minSize: Int { get }
    
    init(payload: Data) throws
}

extension ConstrainedBytes {
    var payload: Data {
        get { return self.payload }
        set {
            guard newValue.count <= Self.maxSize, newValue.count >= Self.minSize else {
                fatalError(
                        "Invalid byte size:  \(newValue.count) for class \(Self.self). Expected size between \(Self.minSize) and \(Self.maxSize), but got \(payload.count)."
                    )
            }
            payload = newValue
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        try self.init(payload: payload)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload
    }
    
    public var debugDescription: String {
        return "\(type(of: self))(hex=\(payload.toHex)"
    }
    
    public var description: String {
        return payload.toHex
    }
}

/// Hash of a Cardano verification key.
struct VerificationKeyHash: ConstrainedBytes, Sendable {
    var payload: Data
    static var maxSize: Int { VERIFICATION_KEY_HASH_SIZE }
    static var minSize: Int { VERIFICATION_KEY_HASH_SIZE }
}

/// Hash of a policy/plutus script.
struct ScriptHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { SCRIPT_HASH_SIZE }
    static var minSize: Int { SCRIPT_HASH_SIZE }
}

typealias PolicyID = ScriptHash
typealias PolicyHash = ScriptHash

/// Hash of script data.
/// See: [alonzo.cddl](https://github.com/input-output-hk/cardano-ledger/blob/525844be05adae151e82069dcd0000f3301ca0d0/eras/alonzo/test-suite/cddl-files/alonzo.cddl#L79-L86)
struct ScriptDataHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { SCRIPT_DATA_HASH_SIZE }
    static var minSize: Int { SCRIPT_DATA_HASH_SIZE }
}

/// Hash of a transaction.
struct TransactionId: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { TRANSACTION_HASH_SIZE }
    static var minSize: Int { TRANSACTION_HASH_SIZE }
}

/// Hash of a datum.
struct DatumHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { DATUM_HASH_SIZE }
    static var minSize: Int { DATUM_HASH_SIZE }
}

/// Hash of auxiliary data.
struct AuxiliaryDataHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { AUXILIARY_DATA_HASH_SIZE }
    static var minSize: Int { AUXILIARY_DATA_HASH_SIZE }
}

/// Hash of a stake pool.
struct PoolKeyHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { POOL_KEY_HASH_SIZE }
    static var minSize: Int { POOL_KEY_HASH_SIZE }
}

/// Hash of a stake pool metadata.
struct PoolMetadataHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { POOL_METADATA_HASH_SIZE }
    static var minSize: Int { POOL_METADATA_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
struct VrfKeyHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { VRF_KEY_HASH_SIZE }
    static var minSize: Int { VRF_KEY_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
struct RewardAccountHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { REWARD_ACCOUNT_HASH_SIZE }
    static var minSize: Int { REWARD_ACCOUNT_HASH_SIZE }
}

/// Hash of a genesis key.
struct GenesisHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { GENESIS_HASH_SIZE }
    static var minSize: Int { GENESIS_HASH_SIZE }
}

/// Hash of a genesis delegate key.
struct GenesisDelegateHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { GENESIS_DELEGATE_HASH_SIZE }
    static var minSize: Int { GENESIS_DELEGATE_HASH_SIZE }
}

/// Hash of a genesis delegate key.
struct AddressKeyHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { ADDRESS_KEY_HASH_SIZE }
    static var minSize: Int { ADDRESS_KEY_HASH_SIZE }
}

/// Hash of a genesis delegate key.
struct AnchorDataHash: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { ANCHOR_DATA_HASH_SIZE }
    static var minSize: Int { ANCHOR_DATA_HASH_SIZE }
}
