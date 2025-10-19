import Foundation
import PotentCBOR


// MARK: - NonNegativeInterval
public struct NonNegativeInterval: CBORSerializable, Hashable, Equatable {
    public var lowerBound: UInt
    public var upperBound: UInt64

    public init(lowerBound: UInt, upperBound: UInt64) {
        precondition(
            lowerBound <= upperBound, "Lower bound must be less than or equal to upper bound")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lowerBound = try container.decode(UInt.self)
        upperBound = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lowerBound)
        try container.encode(upperBound)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.valueError("Invalid NonNegativeInterval type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("NonNegativeInterval must contain exactly 2 elements")
        }
        let lowerBoundPrimitive = elements[0]
        let upperBoundPrimitive = elements[1]
        guard case let .int(lowerBound) = lowerBoundPrimitive,
              case let .int(upperBound) = upperBoundPrimitive else {
            throw CardanoCoreError.valueError("Invalid NonNegativeInterval element types")
        }
        self.init(
            lowerBound: UInt(lowerBound),
            upperBound: UInt64(upperBound)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(lowerBound)),
            .int(Int(upperBound))
        ])
    }

}

// MARK: - UnitInterval
/// A unit interval is a number in the range between 0 and 1
public struct UnitInterval: CBORSerializable, Equatable, Hashable {
    public let numerator: UInt64
    public let denominator: UInt64

    public static let tag = 30

    public init(numerator: UInt64, denominator: UInt64) {
        precondition(
            numerator <= denominator, "Numerator must be less than or equal to denominator")
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }

//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//
//        let cborData = try container.decode(CBOR.self)
//
//        if case let .tagged(tag, cborData) = cborData {
//            guard tag.rawValue == UInt64(UnitInterval.tag) else {
//                throw CardanoCoreError.valueError(
//                    "UnitInterval must be tagged with tag \(UnitInterval.tag)")
//            }
//
//            switch cborData {
//            case .array(let arrayData):
//                guard arrayData.count == 2 else {
//                    throw CardanoCoreError.valueError(
//                        "UnitInterval must contain exactly 2 elements")
//                }
//                self.init(
//                    numerator: arrayData[0].integerValue()!,
//                    denominator: arrayData[1].integerValue()!
//                )
//            default:
//                throw CardanoCoreError.valueError("UnitInterval must be an array")
//            }
//        } else {
//            throw CardanoCoreError.valueError("UnitInterval must be tagged")
//        }
//    }
    
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
                self.init(
                    numerator: UInt64(arrayData[0].intValue!),
                    denominator: UInt64(arrayData[1].intValue!)
                )
            case let .unitInterval(interval):
                self = interval
            default:
                throw CardanoCoreError.valueError("UnitInterval must be tagged")
        }
    }

//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//
//        let cborData: CBOR = .tagged(
//            CBOR.Tag(rawValue: UInt64(UnitInterval.tag)),
//            [
//                .unsignedInt(UInt64(numerator)),
//                .unsignedInt(UInt64(denominator)),
//            ]
//        )
//
//        try container.encode(cborData)
//    }
    
    public func toPrimitive() throws -> Primitive {
        let cborTag = CBORTag(
            tag: UInt64(UnitInterval.tag),
            value: .list([
                .uint(UInt(numerator)),
                .uint(UInt(denominator))
            ])
        )
        return .cborTag(cborTag)
    }
}
