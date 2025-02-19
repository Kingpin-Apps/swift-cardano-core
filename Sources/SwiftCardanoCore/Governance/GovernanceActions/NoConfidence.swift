import Foundation


struct NoConfidence: GovernanceAction {
    static var code: GovActionCode { get { .noConfidence } }
    
    let id: GovActionID
    
    init (id: GovActionID) {
        self.id = id
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid NoConfidence type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
    }
}
