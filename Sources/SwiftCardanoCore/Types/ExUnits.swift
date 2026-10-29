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

    /// CBOR as ``toPrimitive()`` writes it; JSON as the array of the two
    /// prices.
    public init(from decoder: Decoder) throws {
        guard String(describing: type(of: decoder)).contains("JSONDecoder") else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
            return
        }
        var container = try decoder.unkeyedContainer()
        self.init(
            memPrice: try container.decode(NonNegativeInterval.self),
            stepPrice: try container.decode(NonNegativeInterval.self))
    }

    public func encode(to encoder: Encoder) throws {
        guard String(describing: type(of: encoder)).contains("JSONEncoder") else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
            return
        }
        var container = encoder.unkeyedContainer()
        try container.encode(memPrice)
        try container.encode(stepPrice)
    }

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default: throw CardanoCoreError.valueError("Invalid ExUnitPrices type")
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

/// The memory and steps a script may use.
///
/// `ex_units = [mem : uint, steps : uint]`, each at most `Int64.max`: the
/// ledger's `DecCBOR ExUnits`
/// (`libs/cardano-ledger-core/src/Cardano/Ledger/Plutus/ExUnits.hs`) fails on
/// a larger value, so this type refuses one when it reads or writes CBOR.
public struct ExUnits: CBORSerializable, Sendable {
    public var mem: UInt64
    public var steps: UInt64

    /// The largest value either field may hold on chain.
    public static let maxValue = UInt64(Int64.max)

    public init(mem: UInt64, steps: UInt64) {
        self.mem = mem
        self.steps = steps
    }

    /// - Throws: When either field is above ``maxValue``.
    public func validate() throws {
        for (value, what) in [(mem, "mem"), (steps, "steps")] where value > Self.maxValue {
            throw CardanoCoreError.valueError(
                "ExUnits \(what) \(value) is above the ledger's maximum, \(Self.maxValue)")
        }
    }

    /// CBOR as ``toPrimitive()`` writes it; JSON as the array `[mem, steps]`.
    public init(from decoder: Decoder) throws {
        guard String(describing: type(of: decoder)).contains("JSONDecoder") else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
            return
        }
        var container = try decoder.unkeyedContainer()
        self.init(mem: try container.decode(UInt64.self), steps: try container.decode(UInt64.self))
    }

    public func encode(to encoder: Encoder) throws {
        guard String(describing: type(of: encoder)).contains("JSONEncoder") else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
            return
        }
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
        // `0 .. max_int64`, as the ledger reads them.
        let mem: Int64 = try elements[0].integer("ExUnits mem")
        let steps: Int64 = try elements[1].integer("ExUnits steps")
        guard mem >= 0, steps >= 0 else {
            throw CardanoCoreError.valueError("ExUnits must not be negative: [\(mem), \(steps)]")
        }
        self.init(mem: UInt64(mem), steps: UInt64(steps))
    }

    public func toPrimitive() throws -> Primitive {
        try validate()
        return .list([
            .uint(mem),
            .uint(steps),
        ])
    }
}
