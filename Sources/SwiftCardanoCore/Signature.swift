import Foundation

/// The number of bytes in a ``Signature``.
public let SIGNATURE_SIZE = 64


/// A fixed-size signature of ``SIGNATURE_SIZE`` bytes.
public struct Signature: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { SIGNATURE_SIZE }
    public static var minSize: Int { SIGNATURE_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}
