import Foundation
import PotentCBOR

/// Register a stake credential with an optional deposit amount.
struct Register: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Stake Address Registration Certificate" }
    
    public var code: Int { get { return 7 } }
    
    let stakeCredential: StakeCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 7 else {
            throw CardanoCoreError.deserializeError("Invalid Register type: \(code)")
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
