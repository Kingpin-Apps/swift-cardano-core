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
class ConstrainedBytes: Codable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {

    let payload: Data
    class var maxSize: Int { return 0 }
    class var minSize: Int { return 0 }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let payload = try container.decode(Data.self)
        try self.init(payload: payload)
    }
    
    required init(payload: Data) throws {
        guard payload.count <= Self.maxSize, payload.count >= Self.minSize else {
            throw CardanoCoreError
                .valueError(
                    "Invalid byte size:  \(payload.count) for class \(Self.self). Expected size between \(Self.minSize) and \(Self.maxSize), but got \(payload.count)."
                )
        }
        self.payload = payload
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
    
    static func == (lhs: ConstrainedBytes, rhs: ConstrainedBytes) -> Bool {
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
final class VerificationKeyHash: ConstrainedBytes {
    class override var maxSize: Int { VERIFICATION_KEY_HASH_SIZE }
    class override var minSize: Int { VERIFICATION_KEY_HASH_SIZE }
}

/// Hash of a policy/plutus script.
final class ScriptHash: ConstrainedBytes {
    class override var maxSize: Int { SCRIPT_HASH_SIZE }
    class override var minSize: Int { SCRIPT_HASH_SIZE }
}

typealias PolicyID = ScriptHash
typealias PolicyHash = ScriptHash

/// Hash of script data.
/// See: [alonzo.cddl](https://github.com/input-output-hk/cardano-ledger/blob/525844be05adae151e82069dcd0000f3301ca0d0/eras/alonzo/test-suite/cddl-files/alonzo.cddl#L79-L86)
final class ScriptDataHash: ConstrainedBytes {
    class override var maxSize: Int { SCRIPT_DATA_HASH_SIZE }
    class override var minSize: Int { SCRIPT_DATA_HASH_SIZE }
}

/// Hash of a transaction.
final class TransactionId: ConstrainedBytes {
    class override var maxSize: Int { TRANSACTION_HASH_SIZE }
    class override var minSize: Int { TRANSACTION_HASH_SIZE }
}

/// Hash of a datum.
final class DatumHash: ConstrainedBytes {
    class override var maxSize: Int { DATUM_HASH_SIZE }
    class override var minSize: Int { DATUM_HASH_SIZE }
}

/// Hash of auxiliary data.
final class AuxiliaryDataHash: ConstrainedBytes {
    class override var maxSize: Int { AUXILIARY_DATA_HASH_SIZE }
    class override var minSize: Int { AUXILIARY_DATA_HASH_SIZE }
}

/// Hash of a stake pool.
final class PoolKeyHash: ConstrainedBytes {
    class override var maxSize: Int { POOL_KEY_HASH_SIZE }
    class override var minSize: Int { POOL_KEY_HASH_SIZE }
}

/// Hash of a stake pool metadata.
final class PoolMetadataHash: ConstrainedBytes {
    class override var maxSize: Int { POOL_METADATA_HASH_SIZE }
    class override var minSize: Int { POOL_METADATA_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
final class VrfKeyHash: ConstrainedBytes {
    class override var maxSize: Int { VRF_KEY_HASH_SIZE }
    class override var minSize: Int { VRF_KEY_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
final class RewardAccountHash: ConstrainedBytes {
    class override var maxSize: Int { REWARD_ACCOUNT_HASH_SIZE }
    class override var minSize: Int { REWARD_ACCOUNT_HASH_SIZE }
}

/// Hash of a genesis key.
final class GenesisHash: ConstrainedBytes {
    class override var maxSize: Int { GENESIS_HASH_SIZE }
    class override var minSize: Int { GENESIS_HASH_SIZE }
}

/// Hash of a genesis delegate key.
final class GenesisDelegateHash: ConstrainedBytes {
    class override var maxSize: Int { GENESIS_DELEGATE_HASH_SIZE }
    class override var minSize: Int { GENESIS_DELEGATE_HASH_SIZE }
}

/// Hash of a genesis delegate key.
final class AddressKeyHash: ConstrainedBytes {
    class override var maxSize: Int { ADDRESS_KEY_HASH_SIZE }
    class override var minSize: Int { ADDRESS_KEY_HASH_SIZE }
}

/// Hash of a genesis delegate key.
final class AnchorDataHash: ConstrainedBytes {
    class override var maxSize: Int { ANCHOR_DATA_HASH_SIZE }
    class override var minSize: Int { ANCHOR_DATA_HASH_SIZE }
}
