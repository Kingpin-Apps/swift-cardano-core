import Foundation
import PotentCBOR

struct StakeRegisterDelegate: CertificateSerializable, Codable {
    var type: String { get { return StakeRegisterDelegate.TYPE } }
    var description: String { get { return StakeRegisterDelegate.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { "Stake address registration and stake delegation Certificate" }
    
    public var code: Int { get { return 11 } }
    
    let stakeCredential: StakeCredential
    let poolKeyHash: PoolKeyHash
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 11 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        poolKeyHash = try container.decode(PoolKeyHash.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(coin)
    }
}

