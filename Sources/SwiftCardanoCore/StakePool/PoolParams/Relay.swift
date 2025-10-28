import Foundation
import OrderedCollections


public enum Relay: Serializable, Sendable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Relay primitive")
        }
        guard let firstElement = elements.first,
              case let .uint(code) = firstElement else {
            throw CardanoCoreError.deserializeError("Invalid Relay type")
        }
        
        switch code {
            case 0:
                self = .singleHostAddr(try SingleHostAddr(from: primitive))
            case 1:
                self = .singleHostName(try SingleHostName(from: primitive))
            case 2:
                self = .multiHostName(try MultiHostName(from: primitive))
            default:
                throw CardanoCoreError.deserializeError("Invalid Relay type: \(code)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .singleHostAddr(let value):
                return try value.toPrimitive()
            case .singleHostName(let value):
                return try value.toPrimitive()
            case .multiHostName(let value):
                return try value.toPrimitive()
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Relay {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Relay dict")
        }
        if let value = dictValue[.uint(0)] {
            let singleHostAddr = try SingleHostAddr.fromDict(value)
            return .singleHostAddr(singleHostAddr)
        } else if let value = dictValue[.uint(1)] {
            let singleHostName = try SingleHostName.fromDict(value)
            return .singleHostName(singleHostName)
        } else if let value = dictValue[.uint(2)] {
            let multiHostName = try MultiHostName.fromDict(value)
            return .multiHostName(multiHostName)
        } else {
            throw CardanoCoreError.deserializeError("Invalid Relay dictionary")
        }
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        switch self {
            case .singleHostAddr(let value):
                dict[.uint(0)] = try value.toDict()
            case .singleHostName(let value):
                dict[.uint(1)] = try value.toDict()
            case .multiHostName(let value):
                dict[.uint(2)] = try value.toDict()
        }
        return .orderedDict(dict)
    }

}
