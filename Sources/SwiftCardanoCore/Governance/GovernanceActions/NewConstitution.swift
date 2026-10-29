import Foundation


public struct NewConstitution: GovernanceAction {
    public static var code: GovActionCode { get { .newConstitution } }
    
    /// The previous action of the same kind, which this one has to follow.
    ///
    /// The CDDL makes it nullable, and the first action of a chain genuinely has
    /// none — a transaction proposing one cannot be read at all if this is
    /// required.
    public let id: GovActionID?
    public let constitution: Constitution
    
    public init(id: GovActionID?, constitution: Constitution) {
        self.id = id
        self.constitution = constitution
    }
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid NewConstitution primitive")
        }
        let code = try elements[0].integer("NewConstitution code", as: Int.self)
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NewConstitution primitive")
        }
        
        self.id = elements[1] == .null ? nil : try GovActionID(from: elements[1])
        self.constitution = try Constitution(from: elements[2])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
            try constitution.toPrimitive()
        ])
    }
}
