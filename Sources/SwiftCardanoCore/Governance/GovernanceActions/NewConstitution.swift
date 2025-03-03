import Foundation


public struct NewConstitution: GovernanceAction {
    public static var code: GovActionCode { get { .newConstitution } }
    
    public let id: GovActionID
    public let constitution: Constitution
    
    public init(id: GovActionID, constitution: Constitution) {
        self.id = id
        self.constitution = constitution
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NewConstitution type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        constitution = try container.decode(Constitution.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(constitution)
    }
}
