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
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence primitive")
        }
        let code = try elements[0].integer("NoConfidence code", as: Int.self)
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
