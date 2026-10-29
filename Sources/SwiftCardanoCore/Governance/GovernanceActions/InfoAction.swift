import Foundation


public struct InfoAction: GovernanceAction {
    public static var code: GovActionCode { .infoAction }
    
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
