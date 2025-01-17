import Foundation
import PotentCBOR

/// Un-Register a stake credential with an optional refund amount
struct Unregister: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateConway" }
    static var DESCRIPTION: String { "Stake Address Retirement Certificate" }
    
    public var code: Int { get { return 8 } }
    
    let stakeCredential: StakeCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 8 else {
            throw CardanoCoreError.deserializeError("Invalid Unregister type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
        try container.encode(coin)
    }
}

