import Foundation

let SIGNATURE_SIZE = 28


class Signature: ConstrainedBytes {
    class override var maxSize: Int { SIGNATURE_SIZE }
    class override var minSize: Int { SIGNATURE_SIZE }
}
