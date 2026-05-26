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
        default:
            throw CardanoCoreError.valueError("Invalid NonNegativeInterval type: \(primitive)")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("NonNegativeInterval must contain exactly 2 elements")
        }
        func toUInt64(_ p: Primitive) throws -> UInt64 {
            switch p {
            case .int(let v): return UInt64(max(0, v))
            case .uint(let v): return v
            default: throw CardanoCoreError.valueError("NonNegativeInterval element must be integer")
            }
        }
        self.init(lowerBound: try toUInt64(elements[0]), upperBound: try toUInt64(elements[1]))
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(lowerBound)),
            .int(Int64(upperBound))
        ])
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

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let num = try container.decode(UInt64.self, forKey: .numerator)
            let den = try container.decode(UInt64.self, forKey: .denominator)
            self.init(numerator: num, denominator: den)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
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
                guard let numerator = arrayData[0].uint64Value,
                      let denominator = arrayData[1].uint64Value else {
                    throw CardanoCoreError.valueError("UnitInterval elements must be integers")
                }
                self.init(
                    numerator: numerator,
                    denominator: denominator
                )
            case let .unitInterval(interval):
                self = interval
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
