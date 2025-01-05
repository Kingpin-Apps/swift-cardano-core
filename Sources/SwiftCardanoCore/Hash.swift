//
//  Created by Hareem Adderley on 29/06/2024 AT 8:18 AM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//  

import Foundation

let VERIFICATION_KEY_HASH_SIZE = 28,
SCRIPT_HASH_SIZE = 28,
SCRIPT_DATA_HASH_SIZE = 32,
TRANSACTION_HASH_SIZE = 32,
DATUM_HASH_SIZE = 32,
AUXILIARY_DATA_HASH_SIZE = 32,
POOL_KEY_HASH_SIZE = 28,
POOL_METADATA_HASH_SIZE = 32,
VRF_KEY_HASH_SIZE = 32,
REWARD_ACCOUNT_HASH_SIZE = 29

enum CodingKeys: String, CodingKey {
    case payload
}

/// A protocol for byte arrays with constraints on their size.
protocol ConstrainedBytes: CBORSerializable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    var payload: Data { get set }
    var maxSize: Int { get }
    var minSize: Int { get }
    
    init(payload: Data) throws
}

extension ConstrainedBytes {
    func validatePayload(payload: Data) throws {
        // Ensure the payload size is within the constraints
        guard payload.count <= self.maxSize, payload.count >= self.minSize else {
            throw CardanoException
                .valueError(
                    "Invalid byte size:  \(payload.count) for class \(Self.self). Expected size between \(self.minSize) and \(self.maxSize), but got \(payload.count)."
                )
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
    
    func toPrimitive() -> Data {
        return self.payload
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        if let string = value as? String {
            let data = string.hexStringToData
            return try Self.init(payload: data) as! T
        } else if let data = value as? Data {
            return try Self.init(payload: data) as! T
        } else {
            throw CardanoException.valueError("Invalid value type for \(Self.self)")
        }
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(payload, forKey: .payload)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payload = try container.decode(Data.self, forKey: .payload)
        try self.init(payload: payload)
        
        // Ensure the maxSize and minSize are correctly set
        guard self.maxSize == maxSize, self.minSize == minSize else {
            throw CardanoException.decodingException("Size constraints for \(Self.self) are incorrect. Expected max size: \(maxSize), min size: \(minSize).")
        }
    }
}

/// Hash of a Cardano verification key.
struct VerificationKeyHash: ConstrainedBytes {
    var payload: Data
    let maxSize = VERIFICATION_KEY_HASH_SIZE
    let minSize = VERIFICATION_KEY_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a policy/plutus script.
struct ScriptHash: ConstrainedBytes {
    var payload: Data
    let maxSize = SCRIPT_HASH_SIZE
    let minSize = SCRIPT_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of script data.
/// See: [alonzo.cddl](https://github.com/input-output-hk/cardano-ledger/blob/525844be05adae151e82069dcd0000f3301ca0d0/eras/alonzo/test-suite/cddl-files/alonzo.cddl#L79-L86)
struct ScriptDataHash: ConstrainedBytes {
    var payload: Data
    let maxSize = SCRIPT_DATA_HASH_SIZE
    let minSize = SCRIPT_DATA_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a transaction.
struct TransactionId: ConstrainedBytes {
    var payload: Data
    let maxSize = TRANSACTION_HASH_SIZE
    let minSize = TRANSACTION_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a datum.
struct DatumHash: ConstrainedBytes {
    var payload: Data
    let maxSize = DATUM_HASH_SIZE
    let minSize = DATUM_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of auxiliary data.
struct AuxiliaryDataHash: ConstrainedBytes {
    var payload: Data
    let maxSize = AUXILIARY_DATA_HASH_SIZE
    let minSize = AUXILIARY_DATA_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a stake pool.
struct PoolKeyHash: ConstrainedBytes {
    var payload: Data
    let maxSize = POOL_KEY_HASH_SIZE
    let minSize = POOL_KEY_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a stake pool metadata.
struct PoolMetadataHash: ConstrainedBytes {
    var payload: Data
    let maxSize = POOL_METADATA_HASH_SIZE
    let minSize = POOL_METADATA_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a Cardano VRF key.
struct VrfKeyHash: ConstrainedBytes {
    var payload: Data
    let maxSize = VRF_KEY_HASH_SIZE
    let minSize = VRF_KEY_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}

/// Hash of a Cardano VRF key.
struct RewardAccountHash: ConstrainedBytes {
    var payload: Data
    let maxSize = REWARD_ACCOUNT_HASH_SIZE
    let minSize = REWARD_ACCOUNT_HASH_SIZE
    
    init(payload: Data) throws {
        self.payload = payload
        try self.validatePayload(payload: payload)
    }
}
