import Foundation
import PotentCBOR

/// Delegate stake to a `DRep`
struct VoteDelegate: CertificateSerializable, Codable {
    var type: String { get { return VoteDelegate.TYPE } }
    var description: String { get { return VoteDelegate.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { "Vote Delegation Certificate" }
    
    public var code: Int { get { return 9 } }
    
    let stakeCredential: StakeCredential
    let drep: DRep
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 9 else {
            throw CardanoCoreError.deserializeError("Invalid VoteDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        drep = try container.decode(DRep.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(drep)
    }
}
