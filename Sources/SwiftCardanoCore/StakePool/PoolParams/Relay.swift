import Foundation
import OrderedCollections


public enum Relay: Serializable, Sendable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let elements = primitive.arrayElements else {
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
    
    /// Reads ``toDict()``'s form: the relay's own dict, whose `type` says
    /// which kind it is.
    public static func fromDict(_ dict: Primitive) throws -> Relay {
        guard case let .orderedDict(dictValue) = dict, let type = dictValue[.string("type")] else {
            throw CardanoCoreError.deserializeError("Invalid Relay dict: \(dict)")
        }
        switch try type.integer("Relay type", as: Int.self) {
            case SingleHostAddr.code: return .singleHostAddr(try SingleHostAddr.fromDict(dict))
            case SingleHostName.code: return .singleHostName(try SingleHostName.fromDict(dict))
            case MultiHostName.code: return .multiHostName(try MultiHostName.fromDict(dict))
            default: throw CardanoCoreError.deserializeError("Invalid Relay type: \(type)")
        }
    }

    public func toDict() throws -> Primitive {
        switch self {
            case .singleHostAddr(let value): return try value.toDict()
            case .singleHostName(let value): return try value.toDict()
            case .multiHostName(let value): return try value.toDict()
        }
    }

}
