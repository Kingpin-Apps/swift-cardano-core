import Foundation


public struct NoConfidence: GovernanceAction {
    public static var code: GovActionCode { get { .noConfidence } }
    
    /// The previous action of the same kind, which this one has to follow.
    ///
    /// The CDDL makes it nullable, and the first action of a chain genuinely has
    /// none — a transaction proposing one cannot be read at all if this is
    /// required.
    public let id: GovActionID?
    
    public init (id: GovActionID?) {
        self.id = id
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
        }
        
        id = try container.decodeIfPresent(GovActionID.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence primitive")
        }
        let code: Int
        switch elements[0] {
        case .int(let v): code = Int(v)
        case .uint(let v): code = Int(v)
        default: throw CardanoCoreError.deserializeError("Invalid NoConfidence primitive")
        }
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence primitive")
        }
        self.id = elements[1] == .null ? nil : try GovActionID(from: elements[1])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
        ])
    }
}
