import Foundation

public struct AnyTuple: CBORSerializable, Equatable, Hashable {
    public let elements: [Primitive]

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
