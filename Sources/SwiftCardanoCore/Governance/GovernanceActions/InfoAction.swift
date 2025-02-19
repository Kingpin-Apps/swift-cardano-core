import Foundation


struct InfoAction: GovernanceAction {
    static var code: GovActionCode { .infoAction }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid InfoAction type: \(code)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.code)
    }
}
