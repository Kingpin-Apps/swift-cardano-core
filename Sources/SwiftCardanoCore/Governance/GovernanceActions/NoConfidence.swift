import Foundation


public struct NoConfidence: GovernanceAction {
    public static var code: GovActionCode { get { .noConfidence } }
    
    public let id: GovActionID
    
    public init (id: GovActionID) {
        self.id = id
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .int(code) = elements[0],
              code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence primitive")
        }
        
        self.id = try GovActionID(from: elements[1])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Self.code.rawValue),
            try id.toPrimitive()
        ])
    }
}
