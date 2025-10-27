import Foundation

public protocol Serializable: CBORSerializable, JSONSerializable {}

extension Serializable {
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let json = try container.decode(String.self)
            self = try Self.fromJSON(json)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            try self.init(from: primitive)
        }
    }
    
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            let json = try self.toJSON()
            try container.encode(json)
        } else  {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }
}
