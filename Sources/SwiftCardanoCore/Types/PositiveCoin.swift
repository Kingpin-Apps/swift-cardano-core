import Foundation
import OrderedCollections

public struct PositiveCoin: Serializable {

    public let value: UInt

    public init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        // CBOR decodes a positive integer as `.uint`; `.int` comes from
        // values built in code.
        switch primitive {
        case .uint(let value) where value > 0:
            self.init(UInt(value))
        case .int(let value) where value > 0:
            self.init(UInt(value))
        default:
            throw CardanoCoreError.valueError("Invalid PositiveCoin type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        return .int(Int64(value))
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> PositiveCoin {
        guard case let .orderedDict(dictValue) = dict,
              let valuePrimitive = dictValue[.string("value")],
              let coin = try? PositiveCoin(from: valuePrimitive) else {
            throw CardanoCoreError.deserializeError("Invalid or missing value in PositiveCoin dict")
        }
        return coin
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("value")] = .int(Int64(value))
        return .orderedDict(dict)
    }

}

