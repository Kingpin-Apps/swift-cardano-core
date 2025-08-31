import Foundation
import PotentASN1
import PotentCBOR
import PotentCodables
import OrderedCollections


// MARK: - ExUnitPrices
public struct ExUnitPrices: CBORSerializable, Hashable, Equatable {
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
        guard case let .list(elements) = primitive else {
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
            try stepPrice.toPrimitive()
        ])
    }
}

// MARK: - ExUnits
public struct ExUnits: CBORSerializable, Hashable, Equatable {
    public var mem: UInt
    public var steps: UInt

    public init(mem: UInt, steps: UInt) {
        self.mem = mem
        self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(UInt.self)
        steps = try container.decode(UInt.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.valueError("Invalid ExUnits type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("ExUnits must contain exactly 2 elements")
        }
        guard case let .int(mem) = elements[0],
              case let .int(steps) = elements[1] else {
            throw CardanoCoreError.valueError("Invalid ExUnits element types")
        }
        self.init(
            mem: UInt(mem),
            steps: UInt(steps)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(mem)),
            .int(Int(steps))
        ])
    }
}
