import Foundation


/// An info action, which proposes nothing and only records the votes cast on it: `info_action = 6`.
public struct InfoAction: GovernanceAction {
    public static var code: GovActionCode { .infoAction }
    
    /// Creates an info action.
    public init() {}
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 1,
              case let .uint(code) = elements[0],
              code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid InfoAction primitive: \(primitive)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue))
        ])
    }
}
