import Foundation
import CBORCodable


// MARK: - NonNegativeInterval
public struct NonNegativeInterval: CBORSerializable, Sendable {
    public var lowerBound: UInt64
    public var upperBound: UInt64

    public init(lowerBound: UInt64, upperBound: UInt64) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    /// The numerator, which this type has long called ``lowerBound``.
    public var numerator: UInt64 { lowerBound }
    /// The denominator, which this type has long called ``upperBound``.
    public var denominator: UInt64 { upperBound }

    /// `numerator / denominator`, which the ledger's `NonNegativeInterval`
    /// holds as a `Word64` over a `Word64`.
    public init(numerator: UInt64, denominator: UInt64) {
        self.init(lowerBound: numerator, upperBound: denominator)
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lowerBound = try container.decode(UInt64.self)
        upperBound = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lowerBound)
        try container.encode(upperBound)
    }

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let arr):
            elements = arr
        case .cborTag(let tagged) where tagged.tag == 30:
            guard case .list(let arr) = tagged.value else {
                throw CardanoCoreError.valueError("NonNegativeInterval tag-30 value must be an array")
            }
            elements = arr
        case .unitInterval(let interval):
            // The CBOR decoder turns every `#6.30` tag into a `unitInterval`,
            // whatever the ratio actually is, so a non-negative interval
            // arrives in that shape too — and has to be read back out of it.
            elements = [.uint(interval.numerator), .uint(interval.denominator)]
        default:
            throw CardanoCoreError.valueError("Invalid NonNegativeInterval type: \(primitive)")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("NonNegativeInterval must contain exactly 2 elements")
        }
        // `#6.30([uint, positive_int])`: a negative part or a zero
        // denominator is not a non-negative interval.
        func toUInt64(_ p: Primitive) throws -> UInt64 {
            switch p {
            case .int(let v) where v >= 0: return UInt64(v)
            case .uint(let v): return v
            default:
                throw CardanoCoreError.valueError("NonNegativeInterval element must be an unsigned integer: \(p)")
            }
        }
        let denominator = try toUInt64(elements[1])
        guard denominator > 0 else {
            throw CardanoCoreError.valueError("NonNegativeInterval denominator must not be zero")
        }
        self.init(lowerBound: try toUInt64(elements[0]), upperBound: denominator)
    }

    public func toPrimitive() throws -> Primitive {
        // The CDDL's `nonnegative_interval` is `#6.30([uint, positive_int])`.
        // Writing the bare array instead changes the bytes of anything holding
        // one — a pool's pledge influence, the execution unit prices — and so
        // changes the hash of the body it sits in.
        return .cborTag(CBORTag(tag: 30, value: .list([
            .uint(lowerBound),
            .uint(upperBound),
        ])))
    }

}

// MARK: - UnitInterval
/// A unit interval is a number in the range between 0 and 1
public struct UnitInterval: Serializable {
    public let numerator: UInt64
    public let denominator: UInt64

    public static let tag = 30

    private enum CodingKeys: String, CodingKey {
        case numerator, denominator
    }

    public init(numerator: UInt64, denominator: UInt64) {
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }

    /// An interval read from input: the ledger rejects a zero denominator and
    /// a value above one.
    init(checkedNumerator numerator: UInt64, denominator: UInt64) throws {
        guard denominator > 0, numerator <= denominator else {
            throw CardanoCoreError.valueError(
                "A unit interval needs 0 <= \(numerator)/\(denominator) <= 1")
        }
        self.init(numerator: numerator, denominator: denominator)
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let num = try container.decode(UInt64.self, forKey: .numerator)
            let den = try container.decode(UInt64.self, forKey: .denominator)
            try self.init(checkedNumerator: num, denominator: den)
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(numerator, forKey: .numerator)
            try container.encode(denominator, forKey: .denominator)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
            case let .cborTag(tagged):
                guard tagged.tag == UInt64(UnitInterval.tag) else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must be tagged with tag \(UnitInterval.tag)")
                }
                guard case let .list(arrayData) = tagged.value else {
                    throw CardanoCoreError.valueError("UnitInterval must be an array")
                }
                guard arrayData.count == 2 else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must contain exactly 2 elements")
                }
                try self.init(
                    checkedNumerator: try arrayData[0].integer("UnitInterval numerator"),
                    denominator: try arrayData[1].integer("UnitInterval denominator")
                )
            case let .unitInterval(interval):
                try self.init(checkedNumerator: interval.numerator, denominator: interval.denominator)
            default:
                throw CardanoCoreError.valueError("UnitInterval must be tagged")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        let cborTag = CBORTag(
            tag: UInt64(UnitInterval.tag),
            value: .list([
                .uint(numerator),
                .uint(denominator)
            ])
        )
        return .cborTag(cborTag)
    }
}
