import Foundation


public struct HardForkInitiationAction: GovernanceAction {
    public static var code: GovActionCode { get { .hardForkInitiationAction } }
    
    public let id: GovActionID?
    public let protocolVersion: ProtocolVersion
    
    public init(id: GovActionID?, protocolVersion: ProtocolVersion) {
        self.id = id
        self.protocolVersion = protocolVersion
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid HardForkInitiationAction type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        protocolVersion = try container.decode(ProtocolVersion.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(protocolVersion)
    }
}
