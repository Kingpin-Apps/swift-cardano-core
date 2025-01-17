import Foundation
import PotentCBOR

struct StakeVoteRegisterDelegate: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateConway" }
    static var DESCRIPTION: String { "Stake address registration and vote delegation Certificate" }
    
    public var code: Int { get { return 13 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let drep: DRep
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 13 else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        poolKeyHash = try container.decode(PoolKeyHash.self)
        drep = try container.decode(DRep.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(drep)
        try container.encode(coin)
    }
}
