import Foundation

/// A fixed group of values of any type, written as a CBOR array.
public struct AnyTuple: CBORSerializable, Sendable {
    /// The tuple's values, in order.
    public let elements: [Primitive]

    /// Creates a tuple from its values.
    ///
    /// - Parameter elements: The tuple's values, in order.
    public init(_ elements: [Primitive]) { self.elements = elements }

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .list(let arr): self.elements = arr
        default:
            throw CardanoCoreError.valueError("Expected list for AnyTuple")
        }
    }

    public func toPrimitive() throws -> Primitive { .list(elements) }
}
