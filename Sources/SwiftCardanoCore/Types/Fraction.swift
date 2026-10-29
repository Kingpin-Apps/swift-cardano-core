import Foundation
import CBORCodable


public struct Fraction: CBORSerializable, Sendable {
    public let numerator: Int64
    public let denominator: Int64

    public static let tag = 30

    public var quotient: Double {
        return Double(numerator) / Double(denominator)
    }
    public init(numerator: Int64, denominator: Int64) {
        precondition(denominator != 0, "Denominator must not be zero")
        self.numerator = numerator
        self.denominator = denominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            guard tag == UInt64(UnitInterval.tag) else {
                throw CardanoCoreError.valueError(
                    "UnitInterval must be tagged with tag \(UnitInterval.tag)")
            }

            switch cborData {
            case .array(let arrayData):
                guard arrayData.count == 2 else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must contain exactly 2 elements")
                }
                try self.init(
                    from: .cborTag(CBORTag(tag: UInt64(UnitInterval.tag), value: .list([
                        try Primitive.from(cbor: arrayData[0]), try Primitive.from(cbor: arrayData[1]),
                    ]))))
            default:
                throw CardanoCoreError.valueError("UnitInterval must be an array")
            }
        } else {
            throw CardanoCoreError.valueError("UnitInterval must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let cborData: CBOR = .tagged(
            UInt64(UInt64(UnitInterval.tag)),
            [try Primitive.integer(numerator).toCBOR(), try Primitive.integer(denominator).toCBOR()]
        )

        try container.encode(cborData)
    }

    public init(from primitive: Primitive) throws {
        guard case let .cborTag(tagged) = primitive else {
            throw CardanoCoreError.valueError("Invalid CBORTag type")
        }
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

        let numerator: Int64 = try arrayData[0].integer("Fraction numerator")
        let denominator: Int64 = try arrayData[1].integer("Fraction denominator")
        guard denominator != 0 else {
            throw CardanoCoreError.valueError("A fraction's denominator must not be zero")
        }
        self.init(numerator: numerator, denominator: denominator)
    }

    public func toPrimitive() throws -> Primitive {
        let cborTag = CBORTag(
            tag: UInt64(UnitInterval.tag),
            value: .list([.integer(numerator), .integer(denominator)])
        )
        return .cborTag(cborTag)
    }
}
