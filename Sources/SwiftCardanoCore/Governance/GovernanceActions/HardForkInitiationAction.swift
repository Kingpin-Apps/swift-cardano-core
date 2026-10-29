import Foundation


public struct HardForkInitiationAction: GovernanceAction {
    public static var code: GovActionCode { get { .hardForkInitiationAction } }
    
    public let id: GovActionID?
    public let protocolVersion: ProtocolVersion
    
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
