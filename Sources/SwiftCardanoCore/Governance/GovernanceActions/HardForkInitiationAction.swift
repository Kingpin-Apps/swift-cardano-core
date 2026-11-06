import Foundation


/// A proposal to start a hard fork: `hard_fork_initiation_action = (1, gov_action_id / nil, protocol_version)`.
public struct HardForkInitiationAction: GovernanceAction {
    public static var code: GovActionCode { get { .hardForkInitiationAction } }
    
    /// The previous action of the same kind, which this one has to follow, or `nil` for none.
    public let id: GovActionID?
    /// The protocol version to move to.
    public let protocolVersion: ProtocolVersion
    
    /// Creates a hard fork initiation action.
    /// - Parameters:
    ///   - id: The previous hard fork initiation action, or `nil` for none.
    ///   - protocolVersion: The protocol version to move to.
    public init(id: GovActionID?, protocolVersion: ProtocolVersion) {
        self.id = id
        self.protocolVersion = protocolVersion
    }
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction primitive")
        }
        let code = try elements[0].integer("HardForkInitiationAction code", as: Int.self)
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction primitive")
        }
        
        if elements[1] == .null {
            self.id = nil
        } else {
            self.id = try GovActionID(from: elements[1])
        }
        
        self.protocolVersion = try ProtocolVersion(from: elements[2])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
            try protocolVersion.toPrimitive()
        ])
    }
}
