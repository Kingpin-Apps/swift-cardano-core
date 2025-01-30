import Foundation

let SIGNATURE_SIZE = 28


struct Signature: ConstrainedBytes {
    var payload: Data
    static var maxSize: Int { SIGNATURE_SIZE }
    static var minSize: Int { SIGNATURE_SIZE }
}
