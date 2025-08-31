import Foundation

public struct AfterScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidHereAfter
    public let slot: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case slot
    }
    
    public init (slot: Int) {
        self.slot = slot
    }
    
    public init(from decoder: Swift.Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            
            guard typeString == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid BeforeScript type string")
            }
            
            slot = try container.decode(Int.self, forKey: .slot)
        } else {
            var container = try decoder.unkeyedContainer()
            let code = try container.decode(Int.self)
            
            guard code == Self.TYPE.rawValue else {
                throw CardanoCoreError.decodingError("Invalid BeforeScript type: \(code)")
            }
            
            slot = try container.decode(Int.self)
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.TYPE.description(), forKey: .type)
            try container.encode(slot, forKey: .slot)
        } else {
            var container = encoder.unkeyedContainer()
            try container.encode(Self.TYPE.rawValue)
            try container.encode(slot)
        }
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitive)")
        }
        
        guard case let .int(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitiveArray[0])")
            }
        
        guard case let .int(slot) = primitiveArray[1] else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript slot: \(primitiveArray[1])")
        }
        
        self.slot = slot
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Self.TYPE.rawValue),
            .int(slot)
        ])
    }

    
    public static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> AfterScript {
        guard let slot = dict["slot"] as? Int else {
            throw CardanoCoreError.decodingError("Invalid AfterScript slot")
        }
        
        return AfterScript(slot: slot)
    }

}
