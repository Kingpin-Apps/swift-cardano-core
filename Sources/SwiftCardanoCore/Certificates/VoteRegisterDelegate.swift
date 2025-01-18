import Foundation
import PotentCBOR

struct VoteRegisterDelegate: CertificateSerializable, Codable {
    var type: String { get { return VoteRegisterDelegate.TYPE } }
    var description: String { get { return VoteRegisterDelegate.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    
    public var code: Int { get { return 12 } }
    
    let stakeCredential: StakeCredential
    let drep: DRep
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 12 else {
            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        drep = try container.decode(DRep.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(drep)
        try container.encode(coin)
    }
}
