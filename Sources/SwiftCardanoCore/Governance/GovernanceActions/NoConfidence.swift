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
}
