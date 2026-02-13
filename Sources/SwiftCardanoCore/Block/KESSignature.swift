import Foundation
import OrderedCollections

public let KES_SIGNATURE_SIZE = 448
public let KES_VKEY_SIZE = 32

/// KES signature as defined in the Conway CDDL:
/// `kes_signature = bytes .size 448`
public struct KESSignature: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { KES_SIGNATURE_SIZE }
    public static var minSize: Int { KES_SIGNATURE_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}

/// KES verification key as defined in the Conway CDDL:
/// `kes_vkey = bytes .size 32`
public struct KESVKey: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { KES_VKEY_SIZE }
    public static var minSize: Int { KES_VKEY_SIZE }

    public init(payload: Data) {
        self.payload = payload
    }
}
