import Foundation
import PotentCBOR


public struct Fraction: CBORSerializable, Sendable {
    public let numerator: Int
    public let denominator: Int
    
    public static let tag = 30
    
    public var quotient: Double {
        return Double(numerator) / Double(denominator)
    }
    public init(numerator: Int, denominator: Int) {
        precondition(denominator != 0, "Denominator must not be zero")
        self.numerator = numerator
        self.denominator = denominator
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            guard tag.rawValue == UInt64(UnitInterval.tag) else {
                throw CardanoCoreError.valueError(
                    "UnitInterval must be tagged with tag \(UnitInterval.tag)")
            }

            switch cborData {
            case .array(let arrayData):
                guard arrayData.count == 2 else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must contain exactly 2 elements")
                }
                self.init(
                    numerator: arrayData[0].integerValue()!,
                    denominator: arrayData[1].integerValue()!
                )
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
            CBOR.Tag(rawValue: UInt64(UnitInterval.tag)),
            [
                .unsignedInt(UInt64(numerator)),
                .unsignedInt(UInt64(denominator)),
            ]
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
            
        self.init(
            numerator: arrayData[0].intValue!,
            denominator: arrayData[1].intValue!
        )
    }

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
