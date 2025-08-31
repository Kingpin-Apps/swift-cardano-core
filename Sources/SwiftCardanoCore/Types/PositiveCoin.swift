import Foundation

public struct PositiveCoin: CBORSerializable, Equatable, Hashable {
    public let value: UInt

    public init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .int(value) = primitive else {
            throw CardanoCoreError.valueError("Invalid PositiveCoin type")
        }
        self.init(UInt(value))
    }

    public func toPrimitive() throws -> Primitive {
        return .int(Int(value))
    }

}

