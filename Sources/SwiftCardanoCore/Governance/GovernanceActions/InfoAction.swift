import Foundation


public struct InfoAction: GovernanceAction {
    public static var code: GovActionCode { .infoAction }
    
    public init() {}
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid InfoAction type: \(code)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.code)
    }
}
