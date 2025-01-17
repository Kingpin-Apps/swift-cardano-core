import Foundation
import PotentCBOR

struct StakeDelegation: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Stake Delegation Certificate" }
    
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
