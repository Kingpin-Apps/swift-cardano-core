import Foundation

let SIGNATURE_SIZE = 28


public struct Signature: ConstrainedBytes {
    public var payload: Data
    public static var maxSize: Int { SIGNATURE_SIZE }
    public static var minSize: Int { SIGNATURE_SIZE }
    
    public init(payload: Data) {
        self.payload = payload
    }
}
