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
        guard case let .int(value) = primitive else {
            throw CardanoCoreError.valueError("Invalid PositiveCoin type")
        }
        self.init(UInt(value))
    }

    public func toPrimitive() throws -> Primitive {
        return .int(Int(value))
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> PositiveCoin {
        guard case let .orderedDict(dictValue) = dict,
              let valuePrimitive = dictValue[.string("value")],
              case let .int(value) = valuePrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing value in PositiveCoin dict")
        }
        return PositiveCoin(UInt(value))
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("value")] = .int(Int(value))
        return .orderedDict(dict)
    }

}

