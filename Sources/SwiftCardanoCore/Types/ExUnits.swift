import Foundation
import OrderedCollections
import CBORCodable

// MARK: - ExUnitPrices
public struct ExUnitPrices: CBORSerializable, Sendable {
    public var memPrice: NonNegativeInterval
    public var stepPrice: NonNegativeInterval

    public init(memPrice: NonNegativeInterval, stepPrice: NonNegativeInterval) {
        self.memPrice = memPrice
        self.stepPrice = stepPrice
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        memPrice = try container.decode(NonNegativeInterval.self)
        stepPrice = try container.decode(NonNegativeInterval.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(memPrice)
        try container.encode(stepPrice)
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive else {
            throw CardanoCoreError.valueError("Invalid ExUnitPrices type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("ExUnitPrices must contain exactly 2 elements")
        }

        self.memPrice = try NonNegativeInterval(from: elements[0])
        self.stepPrice = try NonNegativeInterval(from: elements[1])
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try memPrice.toPrimitive(),
            try stepPrice.toPrimitive(),
        ])
    }
}

// MARK: - ExUnits
public struct ExUnits: CBORSerializable, Sendable {
    public var mem: UInt64
    public var steps: UInt64

    public init(mem: UInt64, steps: UInt64) {
        self.mem = mem
        self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(UInt64.self)
        steps = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default: throw CardanoCoreError.valueError("Invalid ExUnits type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("ExUnits must contain exactly 2 elements")
        }
        self.init(
            mem: try elements[0].integer("ExUnits mem"),
            steps: try elements[1].integer("ExUnits steps"))
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(mem),
            .uint(steps),
        ])
    }
}
