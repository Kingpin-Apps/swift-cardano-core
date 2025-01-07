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

//enum CodingKeys: String, CodingKey {
//    case payload
//}

/// A protocol for byte arrays with constraints on their size.
class ConstrainedBytes: CBORSerializable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {

    var payload: Data
    class var maxSize: Int { return 0 }
    class var minSize: Int { return 0 }
    
    required init(payload: Data) throws {
        guard payload.count <= Self.maxSize, payload.count >= Self.minSize else {
            throw CardanoException
                .valueError(
                    "Invalid byte size:  \(payload.count) for class \(Self.self). Expected size between \(Self.minSize) and \(Self.maxSize), but got \(payload.count)."
                )
        }
        self.payload = payload
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
    
    func toShallowPrimitive() -> Any {
        return self.payload
    }
    
    func toPrimitive() -> Data {
        return self.payload
    }
    
    class func fromPrimitive<T>(_ value: Any) throws -> T {
        if let string = value as? String {
            let data = string.hexStringToData
            return try Self.init(payload: data) as! T
        } else if let data = value as? Data {
            return try Self.init(payload: data) as! T
        } else {
            throw CardanoException.valueError("Invalid value type for \(Self.self)")
        }
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
    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(payload, forKey: .payload)
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let payload = try container.decode(Data.self, forKey: .payload)
//        try self.init(payload: payload)
//        
//        // Ensure the maxSize and minSize are correctly set
//        guard self.maxSize == maxSize, self.minSize == minSize else {
//            throw CardanoException.decodingException("Size constraints for \(Self.self) are incorrect. Expected max size: \(maxSize), min size: \(minSize).")
//        }
//    }
}

/// Hash of a Cardano verification key.
class VerificationKeyHash: ConstrainedBytes {
    class override var maxSize: Int { VERIFICATION_KEY_HASH_SIZE }
    class override var minSize: Int { VERIFICATION_KEY_HASH_SIZE }
}

/// Hash of a policy/plutus script.
class ScriptHash: ConstrainedBytes {
    class override var maxSize: Int { SCRIPT_HASH_SIZE }
    class override var minSize: Int { SCRIPT_HASH_SIZE }
}

/// Hash of script data.
/// See: [alonzo.cddl](https://github.com/input-output-hk/cardano-ledger/blob/525844be05adae151e82069dcd0000f3301ca0d0/eras/alonzo/test-suite/cddl-files/alonzo.cddl#L79-L86)
class ScriptDataHash: ConstrainedBytes {
    class override var maxSize: Int { SCRIPT_DATA_HASH_SIZE }
    class override var minSize: Int { SCRIPT_DATA_HASH_SIZE }
}

/// Hash of a transaction.
class TransactionId: ConstrainedBytes {
    class override var maxSize: Int { TRANSACTION_HASH_SIZE }
    class override var minSize: Int { TRANSACTION_HASH_SIZE }
}

/// Hash of a datum.
class DatumHash: ConstrainedBytes {
    class override var maxSize: Int { DATUM_HASH_SIZE }
    class override var minSize: Int { DATUM_HASH_SIZE }
}

/// Hash of auxiliary data.
class AuxiliaryDataHash: ConstrainedBytes {
    class override var maxSize: Int { AUXILIARY_DATA_HASH_SIZE }
    class override var minSize: Int { AUXILIARY_DATA_HASH_SIZE }
}

/// Hash of a stake pool.
class PoolKeyHash: ConstrainedBytes {
    class override var maxSize: Int { POOL_KEY_HASH_SIZE }
    class override var minSize: Int { POOL_KEY_HASH_SIZE }
}

/// Hash of a stake pool metadata.
class PoolMetadataHash: ConstrainedBytes {
    class override var maxSize: Int { POOL_METADATA_HASH_SIZE }
    class override var minSize: Int { POOL_METADATA_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
class VrfKeyHash: ConstrainedBytes {
    class override var maxSize: Int { VRF_KEY_HASH_SIZE }
    class override var minSize: Int { VRF_KEY_HASH_SIZE }
}

/// Hash of a Cardano VRF key.
class RewardAccountHash: ConstrainedBytes {
    class override var maxSize: Int { REWARD_ACCOUNT_HASH_SIZE }
    class override var minSize: Int { REWARD_ACCOUNT_HASH_SIZE }
}
