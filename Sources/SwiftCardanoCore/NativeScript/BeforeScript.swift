import Foundation
import OrderedCollections

public struct BeforeScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidBefore
    public let slot: Int
    
    public init (slot: Int) {
        self.slot = slot
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 2,
                case let .uint(code) = primitive[0],
                code == Self.TYPE.rawValue,
              case let .uint(slot) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid BeforeScript type")
        }
        self.slot = Int(slot)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([.uint(UInt(Self.TYPE.rawValue)), .uint(UInt(slot))])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: OrderedDictionary<Primitive, Primitive>) throws -> BeforeScript {
        guard case let .int(slot) = dict[.string("slot")] else {
            throw CardanoCoreError.decodingError("Invalid AfterScript slot")
        }
        
        return BeforeScript(slot: Int(slot))
    }
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(UInt(slot))
        return dict
    }
}
