import Foundation
import PotentCBOR

/// Stake Delegation Certificate
struct StakeDelegation: CertificateSerializable, Codable {
    var type: String { get { return StakeDelegation.TYPE } }
    var description: String { get { return StakeDelegation.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { CertificateDescription.stakeDelegation.rawValue }
    
    public var code: Int { get { return 2 } }
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid StakeDelegation type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        poolKeyHash = try container.decode(PoolKeyHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
    }
}
