import Foundation
import CBORCodable

/// `ex_units = [mem : uint, steps : uint]`.
///
/// The ledger reads each field as a `Word64` and rejects any above
/// `Int64.max` (`Cardano.Ledger.Plutus.ExUnits`), in every era, so that is the
/// range read and written here.
public struct ExecutionUnits: Serializable {

    public var mem: Int64
    public var steps: Int64

    public init(mem: Int64, steps: Int64) {
        self.mem = mem
        self.steps = steps
    }

    /// Reads CBOR through ``init(from:)-(Primitive)``, so either length of
    /// array is read and each field is range-checked; JSON as `[mem, steps]`.
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            var container = try decoder.unkeyedContainer()
            let mem = try container.decode(UInt64.self)
            let steps = try container.decode(UInt64.self)
            try self.init(from: .list([.uint(mem), .uint(steps)]))
        } else {
            try self.init(from: Primitive.decode(from: decoder, preservingEncoding: false))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.unkeyedContainer()
            try container.encode(mem)
            try container.encode(steps)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    /// The sum of each field, held at `Int64.max` (or `Int64.min`) rather
    /// than overflowing: no sum that large fits a transaction anyway.
    public static func + (lhs: ExecutionUnits, rhs: ExecutionUnits) -> ExecutionUnits {
        return ExecutionUnits(
            mem: saturatingSum(lhs.mem, rhs.mem), steps: saturatingSum(lhs.steps, rhs.steps))
    }

    public static func += (lhs: inout ExecutionUnits, rhs: ExecutionUnits) {
        lhs = lhs + rhs
    }

    private static func saturatingSum(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        guard overflow else { return sum }
        return rhs > 0 ? .max : .min
    }

    public func isEmpty() -> Bool {
        return mem == 0 && steps == 0
    }

    /// A field as the ledger reads it: an unsigned integer no larger than
    /// `Int64.max`.
    private static func field(_ primitive: Primitive, _ name: String) throws -> Int64 {
        let value = try primitive.integer("ExecutionUnits \(name)", as: UInt64.self)
        guard let field = Int64(exactly: value) else {
            throw CardanoCoreError.deserializeError(
                "ExecutionUnits \(name): \(value) exceeds Int64.max, which the ledger rejects")
        }
        return field
    }

    public init(from primitive: Primitive) throws {
        guard let elements = primitive.arrayElements, elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ExecutionUnits primitive: \(primitive)")
        }
        self.mem = try Self.field(elements[0], "mem")
        self.steps = try Self.field(elements[1], "steps")
    }

    /// - Throws: When a field is negative: the CDDL has `uint`, so the ledger
    ///   could not read it.
    public func toPrimitive() throws -> Primitive {
        guard mem >= 0, steps >= 0 else {
            throw CardanoCoreError.serializeError(
                "ExecutionUnits cannot be negative: mem \(mem), steps \(steps)")
        }
        return .list([
            .uint(UInt64(mem)),
            .uint(UInt64(steps))
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ExecutionUnits {
        try ExecutionUnits(from: primitive)
    }

    public func toDict() throws -> Primitive {
        return try toPrimitive()
    }
}
