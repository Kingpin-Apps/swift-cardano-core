import Foundation
import PotentCBOR


/// Stake and Vote Delegation Certificate
struct StakeVoteDelegate: CertificateSerializable, Codable {
    var type: String { get { return StakeVoteDelegate.TYPE } }
    var description: String { get { return StakeVoteDelegate.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.stakeVoteDelegate.rawValue }
    
    public var code: Int { get { return 10 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let drep: DRep
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 10 else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        poolKeyHash = try container.decode(PoolKeyHash.self)
        drep = try container.decode(DRep.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(drep)
    }
}
