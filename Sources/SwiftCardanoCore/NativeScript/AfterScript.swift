import Foundation
import OrderedCollections

public struct AfterScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidHereAfter
    public let slot: Int
    
    public init (slot: Int) {
        self.slot = slot
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitive)")
        }
        
        guard case let .uint(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitiveArray[0])")
            }
        
        guard case let .uint(slot) = primitiveArray[1] else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript slot: \(primitiveArray[1])")
        }
        
        self.slot = Int(slot)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.TYPE.rawValue)),
            .uint(UInt(slot))
        ])
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: OrderedDictionary<Primitive, Primitive>) throws -> AfterScript {
        guard case let .int(slot) = dict[.string("slot")] else {
            throw CardanoCoreError.decodingError("Invalid AfterScript slot: \(String(describing: dict[.string("slot")]))")
        }
        
        return AfterScript(slot: Int(slot))
    }
    
    public func toDict() throws -> OrderedDictionary<Primitive, Primitive> {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(UInt(slot))
        return dict
    }

}
