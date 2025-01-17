import Foundation
import PotentCBOR

struct RegisterDRep: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Registration Certificate" }
    
    public var code: Int { get { return 16 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 16 else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep type: \(code)")
        }
        
        drepCredential = try container.decode(DRepCredential.self)
        coin = try container.decode(Coin.self)
        anchor = try container.decodeIfPresent(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(drepCredential)
        try container.encode(coin)
        try container.encode(anchor)
    }
}
